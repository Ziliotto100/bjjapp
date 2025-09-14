// functions/src/index.ts

// Imports Globais
import { onDocumentDeleted, onDocumentCreated } from "firebase-functions/v2/firestore";
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Dependências para a função de compressão de vídeo
import ffmpeg = require("fluent-ffmpeg");
import ffmpeg_static from "ffmpeg-static";
import { v4 as uuidv4 } from "uuid";
import * as path from "path";
import * as os from "os";
import * as fs from "fs";

// Inicializa o Firebase Admin SDK (deve ser feito apenas uma vez)
admin.initializeApp();

// ===============================================================================================
// === SEÇÃO: AUTENTICAÇÃO E SINCRONIZAÇÃO DE USUÁRIOS ============================================
// ===============================================================================================

/**
 * Cloud Function (v2) que sincroniza a exclusão do Firestore com o Auth.
 * Acionada quando um documento na coleção /users é excluído.
 */
export const onuserdeleted = onDocumentDeleted("users/{userId}", async (event) => {
    const userId = event.params.userId;
    functions.logger.log(`Iniciando exclusão do usuário de Auth: ${userId}`);
    
    try {
        await admin.auth().deleteUser(userId);
        functions.logger.log(`Usuário de Auth ${userId} excluído com sucesso.`);
    } catch (error: any) {
        // Se o usuário já foi excluído no Auth, não trata como um erro crítico.
        if (error.code === "auth/user-not-found") {
            functions.logger.warn(`Usuário de Auth ${userId} não foi encontrado.`);
            return;
        }
        functions.logger.error(`Erro ao excluir usuário de Auth ${userId}:`, error);
    }
});


// ===============================================================================================
// === SEÇÃO: PROCESSAMENTO DE SOLICITAÇÕES ======================================================
// ===============================================================================================

/**
 * Processa solicitações de alteração de e-mail criadas na coleção 'emailChangeRequests'.
 */
export const processEmailChangeRequest = onDocumentCreated("emailChangeRequests/{docId}", async (event) => {
    const snap = event.data;
    if (!snap) {
        functions.logger.log("Evento de alteração de e-mail sem dados.");
        return;
    }
    const { targetUid, newEmail } = snap.data();

    if (!targetUid || !newEmail) {
        functions.logger.error("Request inválido. Faltando targetUid ou newEmail.");
        return snap.ref.delete();
    }

    try {
        await admin.auth().updateUser(targetUid, { email: newEmail });
        await admin.firestore().collection("users").doc(targetUid).update({ email: newEmail });
        
        functions.logger.log(`E-mail atualizado com sucesso para UID: ${targetUid}`);
        return snap.ref.delete();
    } catch (error) {
        functions.logger.error("Erro ao processar alteração de e-mail:", error);
        return snap.ref.update({ status: "error", errorMessage: (error as Error).message });
    }
});

/**
 * Processa solicitações de reset de senha criadas na coleção 'passwordResetRequests'.
 */
export const processPasswordResetRequest = onDocumentCreated("passwordResetRequests/{docId}", async (event) => {
    const snap = event.data;
    if (!snap) {
        functions.logger.log("Evento de reset de senha sem dados.");
        return;
    }
    const { targetUid } = snap.data();

    if (!targetUid) {
        functions.logger.error("Request inválido. Faltando targetUid.");
        return snap.ref.delete();
    }

    const temporaryPassword = "mudar123";

    try {
        await admin.auth().updateUser(targetUid, { password: temporaryPassword });
        await admin.firestore().collection("users").doc(targetUid).update({ mustChangePassword: true });
        
        functions.logger.log(`Senha resetada com sucesso para UID: ${targetUid}`);
        return snap.ref.delete();
    } catch (error) {
        functions.logger.error("Erro ao processar reset de senha:", error);
        return snap.ref.update({ status: "error", errorMessage: (error as Error).message });
    }
});


// ===============================================================================================
// === SEÇÃO: PROCESSAMENTO DE VÍDEOS ============================================================
// ===============================================================================================

/**
 * Comprime vídeos após o upload no Storage.
 * Acionada pela criação de um documento em /academies/{academyId}/videos/{videoId}.
 */
export const compressVideo = functions
    .region("southamerica-east1")
    .runWith({
        timeoutSeconds: 540,
        memory: "1GB",
    })
    .firestore.document("academies/{academyId}/videos/{videoId}")
    .onCreate(async (snap, context) => {
        const videoData = snap.data();

        if (videoData.videoType !== "uploaded" || videoData.processingStatus === "complete") {
            return null; // Ignora se não for upload ou já processado
        }

        const videoUrl = videoData.videoUrl;
        const bucket = admin.storage().bucket();
        
        const originalFilePath = new URL(videoUrl).pathname.split("/o/")[1].split("?")[0];
        const decodedPath = decodeURIComponent(originalFilePath);
        const file = bucket.file(decodedPath);
        
        const tempFileName = uuidv4();
        const tempFilePath = path.join(os.tmpdir(), tempFileName);
        const compressedTempPath = path.join(os.tmpdir(), `compressed_${tempFileName}.mp4`);
        const finalCompressedPath = path.join(path.dirname(decodedPath), `compressed_${path.basename(decodedPath)}`);
        
        try {
            await file.download({ destination: tempFilePath });
            functions.logger.log(`Vídeo baixado para: ${tempFilePath}`);
            
            await new Promise<void>((resolve, reject) => {
                if (!ffmpeg_static) {
                  return reject(new Error("Caminho do ffmpeg-static não encontrado."));
                }
                ffmpeg(tempFilePath)
                    .setFfmpegPath(ffmpeg_static as string)
                    .outputOptions([
                        "-vf", "scale='min(1280,iw)':-2",
                        "-c:v", "libx264", "-preset", "veryfast", "-crf", "28",
                        "-c:a", "aac", "-b:a", "128k",
                    ])
                    // <<< A CORREÇÃO ESTÁ AQUI >>>
                    // Adicionamos os parâmetros (stdout, stderr) à função de callback, mesmo que não sejam usados.
                    .on("end", (stdout, stderr) => {
                        functions.logger.log("Compressão FFmpeg finalizada com sucesso.");
                        resolve();
                    })
                    .on("error", (err: Error) => {
                        functions.logger.error("Erro no FFmpeg:", err);
                        reject(err);
                    })
                    .save(compressedTempPath);
            });

            const [compressedFile] = await bucket.upload(compressedTempPath, {
                destination: finalCompressedPath,
                metadata: { contentType: "video/mp4" },
            });
            
            await compressedFile.makePublic();
            const newUrl = compressedFile.publicUrl();
            const newSize = (await compressedFile.getMetadata())[0].size;

            await snap.ref.update({
                videoUrl: newUrl,
                fileSizeBytes: newSize,
                processingStatus: "complete",
            });
            
            await file.delete();
            functions.logger.log("Processo concluído e arquivo original deletado.");

        } catch (error) {
            functions.logger.error("Falha no pipeline de compressão:", error);
            await snap.ref.update({ processingStatus: "failed", error: (error as Error).message });
        } finally {
            // Garante que os arquivos temporários sejam sempre limpos
            fs.unlinkSync(tempFilePath);
            fs.unlinkSync(compressedTempPath);
        }
        return null;
    });


// ===============================================================================================
// === SEÇÃO: ENVIO DE NOTIFICAÇÕES ==============================================================
// ===============================================================================================

/**
 * Envia notificações push com base em solicitações na coleção 'notification_requests'.
 */
export const sendPushNotifications = onDocumentCreated("notification_requests/{requestId}", async (event) => {
    const snap = event.data;
    if (!snap) {
        functions.logger.log("Evento de notificação sem dados.");
        return;
    }
    const { title, body, sendToAll, academyIds } = snap.data();

    const db = admin.firestore();
    const messaging = admin.messaging();
    let usersQuery;

    if (sendToAll) {
        usersQuery = db.collection("users").where("role", "!=", "superadmin");
    } else {
        if (!academyIds || academyIds.length === 0) {
            return snap.ref.update({ status: "failed", error: "Nenhuma academia selecionada" });
        }
        usersQuery = db.collection("users").where("academyId", "in", academyIds);
    }
    
    try {
        const usersSnapshot = await usersQuery.get();
        const tokens = usersSnapshot.docs.flatMap(doc => doc.data().fcmTokens || []);

        if (tokens.length === 0) {
            return snap.ref.update({ status: "complete", details: "Nenhum token encontrado" });
        }
        
        const uniqueTokens = [...new Set(tokens)];
        
        const message = {
            notification: { title, body },
            tokens: uniqueTokens,
        };
        
        const response = await messaging.sendEachForMulticast(message);
        
        return snap.ref.update({
            status: "complete",
            sentCount: response.successCount,
            failedCount: response.failureCount,
        });
    } catch (error) {
        functions.logger.error("Erro ao enviar notificações:", error);
        return snap.ref.update({ status: "failed", error: (error as Error).message });
    }
});
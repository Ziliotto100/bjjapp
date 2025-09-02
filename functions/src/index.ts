// functions/src/index.ts

import { onDocumentDeleted, onDocumentCreated } from "firebase-functions/v2/firestore";
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Dependências para a nova função de compressão (CORRIGIDO)
import ffmpeg = require("fluent-ffmpeg"); // <<< ESTA É A LINHA CORRIGIDA
import ffmpeg_static from "ffmpeg-static";
import { v4 as uuidv4 } from "uuid";
import * as path from "path";
import * as os from "os";
import * as fs from "fs";


admin.initializeApp();

/**
 * Cloud Function (v2) que é acionada quando um documento na coleção /users
 * é excluído. Ela então exclui o usuário correspondente do Firebase Auth.
 */
export const onuserdeleted = onDocumentDeleted("users/{userId}", async (event) => {
    const userId = event.params.userId;
    functions.logger.log(`Iniciando exclusão do usuário de Auth: ${userId}`);
    try {
        await admin.auth().deleteUser(userId);
        functions.logger.log(`Usuário de Auth ${userId} excluído com sucesso.`);
    }
    catch (error: any) {
        if (error.code === "auth/user-not-found") {
            functions.logger.warn(`Usuário de Auth ${userId} não foi encontrado. ` +
                "Pode já ter sido excluído.");
            return;
        }
        functions.logger.error(`Erro ao excluir usuário de Auth ${userId}:`, error);
    }
});

/**
 * Cloud Function (v2) que processa solicitações de alteração de e-mail.
 */
export const processEmailChangeRequest = onDocumentCreated("emailChangeRequests/{docId}", async (event) => {
    const snap = event.data;
    if (!snap) {
        functions.logger.log("Evento sem dados, abortando.");
        return;
    }
    const requestData = snap.data();
    const { targetUid, newEmail } = requestData;

    if (!targetUid || !newEmail) {
        functions.logger.log("Request is missing targetUid or newEmail. Aborting.");
        return snap.ref.delete();
    }

    try {
        await admin.auth().updateUser(targetUid, {
            email: newEmail,
        });
        functions.logger.log(`Successfully updated email in Auth for UID: ${targetUid}`);

        await admin.firestore().collection("users").doc(targetUid).update({
            email: newEmail,
        });
        functions.logger.log(`Successfully updated email in Firestore for UID: ${targetUid}`);

        return snap.ref.delete();
    } catch (error) {
        functions.logger.error("Error processing email change request:", error);
        return snap.ref.update({ status: "error", errorMessage: (error as Error).message });
    }
});

/**
 * Cloud Function (v2) que processa solicitações de reset de senha.
 */
export const processPasswordResetRequest = onDocumentCreated("passwordResetRequests/{docId}", async (event) => {
    const snap = event.data;
    if (!snap) {
        functions.logger.log("Evento sem dados para reset de senha, abortando.");
        return;
    }
    const requestData = snap.data();
    const { targetUid } = requestData;

    if (!targetUid) {
        functions.logger.log("Request is missing targetUid. Aborting.");
        return snap.ref.delete();
    }

    const temporaryPassword = 'mudar123';

    try {
        // 1. Altera a senha no Firebase Authentication
        await admin.auth().updateUser(targetUid, {
            password: temporaryPassword,
        });
        functions.logger.log(`Successfully reset password in Auth for UID: ${targetUid}`);

        // 2. Força o usuário a alterar a senha no próximo login
        await admin.firestore().collection("users").doc(targetUid).update({
            mustChangePassword: true,
        });
        functions.logger.log(`Successfully set mustChangePassword flag in Firestore for UID: ${targetUid}`);

        // 3. Deleta a solicitação
        return snap.ref.delete();
    } catch (error) {
        functions.logger.error("Error processing password reset request:", error);
        return snap.ref.update({ status: "error", errorMessage: (error as Error).message });
    }
});


/**
 * **FUNÇÃO ADICIONADA**
 * Cloud Function (v1) que comprime vídeos enviados para o Storage.
 */
export const compressVideo = functions
    .region("southamerica-east1") // Define a região para São Paulo
    .runWith({
        timeoutSeconds: 540, // Aumenta o tempo limite para 9 mins para vídeos longos
        memory: "1GB",       // Aumenta a memória para processamento de vídeo
    })
    .firestore.document("academies/{academyId}/videos/{videoId}")
    .onCreate(async (snap, context) => {
        const videoData = snap.data();

        // 1. VERIFICAÇÃO INICIAL
        if (videoData.videoType !== "uploaded" || videoData.processingStatus === "complete") {
            functions.logger.log("Gatilho ignorado: não é um vídeo de upload ou já foi processado.");
            return null;
        }

        const videoUrl = videoData.videoUrl;
        const bucket = admin.storage().bucket();

        const originalFilePath = new URL(videoUrl).pathname.split("/o/")[1].split("?")[0];
        const decodedPath = decodeURIComponent(originalFilePath);
        const file = bucket.file(decodedPath);

        const tempFilePath = path.join(os.tmpdir(), uuidv4());

        functions.logger.log(`Iniciando download do vídeo original: ${decodedPath}`);
        await file.download({ destination: tempFilePath });
        functions.logger.log(`Download concluído para: ${tempFilePath}`);

        const compressedFileName = `compressed_${path.basename(decodedPath)}`;
        const compressedTempPath = path.join(os.tmpdir(), compressedFileName);
        const compressedFilePath = path.join(path.dirname(decodedPath), compressedFileName);

        functions.logger.log("Iniciando compressão com FFmpeg...");

        // 2. COMPRESSÃO DO VÍDEO
        await new Promise<void>((resolve, reject) => {
            if (!ffmpeg_static) {
                reject(new Error("Caminho do ffmpeg-static não encontrado."));
                return;
            }
            ffmpeg(tempFilePath)
                .setFfmpegPath(ffmpeg_static as string)
                .outputOptions([
                    "-vf", "scale='min(1280,iw)':-2",
                    "-c:v", "libx264",
                    "-preset", "veryfast",
                    "-crf", "28",
                    "-c:a", "aac",
                    "-b:a", "128k",
                ])
                .on("end", () => {
                    functions.logger.log("Compressão FFmpeg finalizada com sucesso.");
                    resolve();
                })
                .on("error", (err: Error) => {
                    functions.logger.error("Erro no FFmpeg:", err);
                    reject(err);
                })
                .save(compressedTempPath);
        });

        // 3. UPLOAD DO VÍDEO COMPRIMIDO
        functions.logger.log(`Iniciando upload do vídeo comprimido para: ${compressedFilePath}`);
        const [compressedFile] = await bucket.upload(compressedTempPath, {
            destination: compressedFilePath,
            metadata: {
                contentType: "video/mp4",
            },
        });

        await compressedFile.makePublic();
        const newUrl = compressedFile.publicUrl();
        const newSize = (await compressedFile.getMetadata())[0].size;
        functions.logger.log(`Upload concluído. Nova URL: ${newUrl}`);

        // 4. ATUALIZA O BANCO DE DADOS
        await snap.ref.update({
            videoUrl: newUrl,
            fileSizeBytes: newSize,
            processingStatus: "complete",
        });

        // 5. LIMPEZA
        functions.logger.log(`Limpando arquivos. Deletando original: ${decodedPath}`);
        await file.delete();
        fs.unlinkSync(tempFilePath);
        fs.unlinkSync(compressedTempPath);
        functions.logger.log("Limpeza concluída.");

        return null;
    });
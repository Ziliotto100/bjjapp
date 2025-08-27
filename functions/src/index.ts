// functions/src/index.ts

import { onDocumentDeleted, onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

/**
 * Cloud Function (v2) que é acionada quando um documento na coleção /users
 * é excluído. Ela então exclui o usuário correspondente do Firebase Auth.
 */
export const onuserdeleted = onDocumentDeleted("users/{userId}", async (event) => {
    const userId = event.params.userId;
    logger.log(`Iniciando exclusão do usuário de Auth: ${userId}`);
    try {
        await admin.auth().deleteUser(userId);
        logger.log(`Usuário de Auth ${userId} excluído com sucesso.`);
    }
    catch (error: any) {
        if (error.code === "auth/user-not-found") {
            logger.warn(`Usuário de Auth ${userId} não foi encontrado. ` +
                "Pode já ter sido excluído.");
            return;
        }
        logger.error(`Erro ao excluir usuário de Auth ${userId}:`, error);
    }
});

/**
 * Cloud Function (v2) que processa solicitações de alteração de e-mail.
 */
export const processEmailChangeRequest = onDocumentCreated("emailChangeRequests/{docId}", async (event) => {
    const snap = event.data;
    if (!snap) {
        logger.log("Evento sem dados, abortando.");
        return;
    }
    const requestData = snap.data();
    const { targetUid, newEmail } = requestData;

    if (!targetUid || !newEmail) {
        logger.log("Request is missing targetUid or newEmail. Aborting.");
        return snap.ref.delete();
    }

    try {
        await admin.auth().updateUser(targetUid, {
            email: newEmail,
        });
        logger.log(`Successfully updated email in Auth for UID: ${targetUid}`);

        await admin.firestore().collection("users").doc(targetUid).update({
            email: newEmail,
        });
        logger.log(`Successfully updated email in Firestore for UID: ${targetUid}`);

        return snap.ref.delete();
    } catch (error) {
        logger.error("Error processing email change request:", error);
        return snap.ref.update({ status: "error", errorMessage: (error as Error).message });
    }
});

/**
 * **NOVA FUNÇÃO**
 * Cloud Function (v2) que processa solicitações de reset de senha.
 */
export const processPasswordResetRequest = onDocumentCreated("passwordResetRequests/{docId}", async (event) => {
    const snap = event.data;
    if (!snap) {
        logger.log("Evento sem dados para reset de senha, abortando.");
        return;
    }
    const requestData = snap.data();
    const { targetUid } = requestData;

    if (!targetUid) {
        logger.log("Request is missing targetUid. Aborting.");
        return snap.ref.delete();
    }

    const temporaryPassword = 'mudar123';

    try {
        // 1. Altera a senha no Firebase Authentication
        await admin.auth().updateUser(targetUid, {
            password: temporaryPassword,
        });
        logger.log(`Successfully reset password in Auth for UID: ${targetUid}`);

        // 2. Força o usuário a alterar a senha no próximo login
        await admin.firestore().collection("users").doc(targetUid).update({
            mustChangePassword: true,
        });
        logger.log(`Successfully set mustChangePassword flag in Firestore for UID: ${targetUid}`);

        // 3. Deleta a solicitação
        return snap.ref.delete();
    } catch (error) {
        logger.error("Error processing password reset request:", error);
        return snap.ref.update({ status: "error", errorMessage: (error as Error).message });
    }
});

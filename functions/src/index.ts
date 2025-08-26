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
    catch (error: any) { // Adicionado 'any' para tipagem do erro
        if (error.code === "auth/user-not-found") {
            logger.warn(`Usuário de Auth ${userId} não foi encontrado. ` +
                "Pode já ter sido excluído.");
            return;
        }
        logger.error(`Erro ao excluir usuário de Auth ${userId}:`, error);
    }
});

/**
 * Cloud Function (v2) que é acionada quando um novo documento é criado
 * em /emailChangeRequests. Ela atualiza o e-mail do usuário no
 * Firebase Auth e no Firestore.
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
        // 1. Atualiza o e-mail no Firebase Authentication
        await admin.auth().updateUser(targetUid, {
            email: newEmail,
        });
        logger.log(`Successfully updated email in Auth for UID: ${targetUid}`);

        // 2. Atualiza o e-mail na coleção de usuários do Firestore
        await admin.firestore().collection("users").doc(targetUid).update({
            email: newEmail,
        });
        logger.log(`Successfully updated email in Firestore for UID: ${targetUid}`);

        // 3. Deleta o documento de solicitação após o processamento
        return snap.ref.delete();
    } catch (error) {
        logger.error("Error processing email change request:", error);
        // Opcional: Atualiza o documento com um status de erro em vez de deletar
        return snap.ref.update({ status: "error", errorMessage: (error as Error).message });
    }
});

import {onDocumentDeleted} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions";
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
    logger.log(
        `Usuário de Auth ${userId} excluído com sucesso.`
    );
  } catch (error: any) {
    if (error.code === "auth/user-not-found") {
      logger.warn(
          `Usuário de Auth ${userId} não foi encontrado. ` +
          "Pode já ter sido excluído."
      );
      return;
    }    logger.error(
        `Erro ao excluir usuário de Auth ${userId}:`,
        error
    );
  }
});
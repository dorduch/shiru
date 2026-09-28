import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {defineSecret} from "firebase-functions/params";
import {HttpsError} from "firebase-functions/v2/https";

initializeApp();
export const db = getFirestore();
export const bucket = getStorage().bucket();

export const ELEVENLABS_BASE = process.env.ELEVENLABS_BASE_URL ?? "https://api.elevenlabs.io";
export const INVITE_HOST = "https://shiru-bcdd2.web.app";

export const anthropicKey = defineSecret("ANTHROPIC_API_KEY");
export const elevenLabsKey = defineSecret("ELEVENLABS_API_KEY");
export const wallyVoice = defineSecret("ELEVENLABS_VOICE_WALLY");
export const fernVoice = defineSecret("ELEVENLABS_VOICE_FERN");
export const rayVoice = defineSecret("ELEVENLABS_VOICE_RAY");

export function requireTrusted(request: {auth?: unknown; app?: unknown}): asserts request is {auth: {uid: string; token: Record<string, unknown>}; app: unknown} {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in is required.");
  if (!request.app) throw new HttpsError("failed-precondition", "App Check is required.");
}

import { Redis } from 'ioredis'

export const redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379')

// --- Tokens ---

interface Tokens {
  access_token: string
  refresh_token: string
}

export async function setTokens(userId: string, tokens: Tokens): Promise<void> {
  await redis.set(`user:${userId}:tokens`, JSON.stringify(tokens))
}

export async function getTokens(userId: string): Promise<Tokens | null> {
  const raw = await redis.get(`user:${userId}:tokens`)
  return raw ? (JSON.parse(raw) as Tokens) : null
}

// --- Now Playing ---

export interface NowPlayingPayload {
  track: string
  artist: string
  albumArt: string
  timestamp: number
}

export async function setNowPlaying(userId: string, payload: NowPlayingPayload): Promise<void> {
  await redis.set(`user:${userId}:now_playing`, JSON.stringify(payload), 'EX', 60)
}

export async function getNowPlaying(userId: string): Promise<NowPlayingPayload | null> {
  const raw = await redis.get(`user:${userId}:now_playing`)
  return raw ? (JSON.parse(raw) as NowPlayingPayload) : null
}

export async function setLastPlayed(userId: string, payload: NowPlayingPayload): Promise<void> {
  await redis.set(`user:${userId}:last_played`, JSON.stringify(payload))
}

export async function getLastPlayed(userId: string): Promise<NowPlayingPayload | null> {
  const raw = await redis.get(`user:${userId}:last_played`)
  return raw ? (JSON.parse(raw) as NowPlayingPayload) : null
}

// --- Group ---

export async function addUserToGroup(userId: string): Promise<void> {
  await redis.sadd('users:all', userId)
}

export async function removeUserFromGroup(userId: string): Promise<void> {
  await redis.srem('users:all', userId)
  await redis.del(
    `user:${userId}:last_played`,
    `user:${userId}:now_playing`,
    `user:${userId}:displayName`,
    `user:${userId}:device_token`,
    `user:${userId}:session_token`,
  )
}

export async function getAllUserIds(): Promise<string[]> {
  return redis.smembers('users:all')
}

// --- Session Tokens ---

export async function setSessionToken(userId: string, token: string): Promise<void> {
  await redis.set(`user:${userId}:session_token`, token)
}

export async function getSessionToken(userId: string): Promise<string | null> {
  return redis.get(`user:${userId}:session_token`)
}

// --- Display Names ---

export async function setUserDisplayName(userId: string, name: string): Promise<void> {
  await redis.set(`user:${userId}:displayName`, name)
}

export async function getUserDisplayName(userId: string): Promise<string | null> {
  return redis.get(`user:${userId}:displayName`)
}


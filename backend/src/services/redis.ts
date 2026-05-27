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

// --- Pairs ---

interface PairMembers {
  userA: string
  userB: string
}

export async function setPair(pairId: string, members: PairMembers): Promise<void> {
  await redis.set(`pair:${pairId}`, JSON.stringify(members))
}

export async function getPair(pairId: string): Promise<PairMembers | null> {
  const raw = await redis.get(`pair:${pairId}`)
  return raw ? (JSON.parse(raw) as PairMembers) : null
}

// --- Display Names ---

export async function setUserDisplayName(userId: string, name: string): Promise<void> {
  await redis.set(`user:${userId}:displayName`, name)
}

export async function getUserDisplayName(userId: string): Promise<string | null> {
  return redis.get(`user:${userId}:displayName`)
}

// --- User → PairId reverse lookup ---

export async function setUserPairId(userId: string, pairId: string): Promise<void> {
  await redis.set(`user:${userId}:pairId`, pairId)
}

export async function getUserPairId(userId: string): Promise<string | null> {
  return redis.get(`user:${userId}:pairId`)
}

import { getTokens, setTokens, type NowPlayingPayload } from './redis.js'

const SPOTIFY_TOKEN_URL = 'https://accounts.spotify.com/api/token'
const SPOTIFY_API_BASE = 'https://api.spotify.com/v1'

const CLIENT_ID = process.env.SPOTIFY_CLIENT_ID!
const CLIENT_SECRET = process.env.SPOTIFY_CLIENT_SECRET!
const REDIRECT_URI = process.env.SPOTIFY_REDIRECT_URI!

function basicAuthHeader(): string {
  return 'Basic ' + Buffer.from(`${CLIENT_ID}:${CLIENT_SECRET}`).toString('base64')
}

export interface ExchangeResult {
  userId: string
  access_token: string
  refresh_token: string
}

export async function exchangeCode(code: string, codeVerifier: string): Promise<ExchangeResult> {
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    redirect_uri: REDIRECT_URI,
    client_id: CLIENT_ID,
    code_verifier: codeVerifier,
  })

  const tokenRes = await fetch(SPOTIFY_TOKEN_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Authorization: basicAuthHeader(),
    },
    body,
  })

  if (!tokenRes.ok) {
    throw new Error(`Token exchange failed: ${tokenRes.status}`)
  }

  const tokens = (await tokenRes.json()) as { access_token: string; refresh_token: string }

  const meRes = await fetch(`${SPOTIFY_API_BASE}/me`, {
    headers: { Authorization: `Bearer ${tokens.access_token}` },
  })

  if (!meRes.ok) {
    throw new Error(`GET /me failed: ${meRes.status}`)
  }

  const me = (await meRes.json()) as { id: string }

  return { userId: me.id, access_token: tokens.access_token, refresh_token: tokens.refresh_token }
}

export async function refreshAccessToken(userId: string): Promise<string> {
  const stored = await getTokens(userId)
  if (!stored) throw new Error(`No tokens found for user ${userId}`)

  const body = new URLSearchParams({
    grant_type: 'refresh_token',
    refresh_token: stored.refresh_token,
  })

  const res = await fetch(SPOTIFY_TOKEN_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Authorization: basicAuthHeader(),
    },
    body,
  })

  if (!res.ok) throw new Error(`Token refresh failed: ${res.status}`)

  const data = (await res.json()) as { access_token: string; refresh_token?: string }

  await setTokens(userId, {
    access_token: data.access_token,
    refresh_token: data.refresh_token ?? stored.refresh_token,
  })

  return data.access_token
}

export async function fetchNowPlaying(userId: string): Promise<NowPlayingPayload | null> {
  const tokens = await getTokens(userId)
  if (!tokens) return null

  const result = await callNowPlaying(tokens.access_token)

  if (result === 'unauthorized') {
    const newToken = await refreshAccessToken(userId)
    const retry = await callNowPlaying(newToken)
    if (retry === 'unauthorized' || retry === 'not_playing') return null
    return retry
  }

  if (result === 'not_playing') return null
  return result
}

async function callNowPlaying(
  accessToken: string,
): Promise<NowPlayingPayload | 'not_playing' | 'unauthorized'> {
  const res = await fetch(`${SPOTIFY_API_BASE}/me/player/currently-playing`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  })

  if (res.status === 204 || res.status === 404) return 'not_playing'
  if (res.status === 401) return 'unauthorized'
  if (!res.ok) return 'not_playing'

  const data = (await res.json()) as {
    item?: { name: string; artists: { name: string }[]; album: { images: { url: string }[] } }
    is_playing?: boolean
  }

  if (!data.item || !data.is_playing) return 'not_playing'

  return {
    track: data.item.name,
    artist: data.item.artists.map((a) => a.name).join(', '),
    albumArt: data.item.album.images[0]?.url ?? '',
    timestamp: Date.now(),
  }
}

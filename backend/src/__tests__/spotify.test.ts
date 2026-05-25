import { describe, it, expect, vi, beforeEach } from 'vitest'

// Mock redis module before importing spotify
vi.mock('../services/redis.js', () => ({
  getTokens: vi.fn(),
  setTokens: vi.fn(),
}))

import { refreshAccessToken, fetchNowPlaying } from '../services/spotify.js'
import * as redisModule from '../services/redis.js'

const getTokens = vi.mocked(redisModule.getTokens)
const setTokens = vi.mocked(redisModule.setTokens)

beforeEach(() => {
  vi.clearAllMocks()
  vi.stubEnv('SPOTIFY_CLIENT_ID', 'test-client-id')
  vi.stubEnv('SPOTIFY_CLIENT_SECRET', 'test-client-secret')
  vi.stubEnv('SPOTIFY_REDIRECT_URI', 'tunelinkapp://auth/callback')
})

// --- 8.1: refreshAccessToken ---

describe('refreshAccessToken', () => {
  it('reads refresh_token from Redis, calls Spotify, writes new access_token back', async () => {
    getTokens.mockResolvedValue({
      access_token: 'old-access',
      refresh_token: 'stored-refresh',
    })
    setTokens.mockResolvedValue(undefined)

    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ access_token: 'new-access', refresh_token: 'new-refresh' }),
    })
    vi.stubGlobal('fetch', mockFetch)

    const result = await refreshAccessToken('user123')

    expect(result).toBe('new-access')
    expect(setTokens).toHaveBeenCalledWith('user123', {
      access_token: 'new-access',
      refresh_token: 'new-refresh',
    })
  })

  it('throws when no tokens found in Redis', async () => {
    getTokens.mockResolvedValue(null)
    await expect(refreshAccessToken('unknown')).rejects.toThrow('No tokens found')
  })

  it('preserves old refresh_token when Spotify omits it in response', async () => {
    getTokens.mockResolvedValue({ access_token: 'old', refresh_token: 'keep-this' })
    setTokens.mockResolvedValue(undefined)

    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ access_token: 'fresh' }),
    }))

    await refreshAccessToken('user123')

    expect(setTokens).toHaveBeenCalledWith('user123', {
      access_token: 'fresh',
      refresh_token: 'keep-this',
    })
  })
})

// --- 8.2: fetchNowPlaying ---

describe('fetchNowPlaying', () => {
  it('returns null when Spotify responds 204 (nothing playing)', async () => {
    getTokens.mockResolvedValue({ access_token: 'tok', refresh_token: 'ref' })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ status: 204, ok: false }))

    const result = await fetchNowPlaying('user1')
    expect(result).toBeNull()
  })

  it('returns null when item is null (private session / no track)', async () => {
    getTokens.mockResolvedValue({ access_token: 'tok', refresh_token: 'ref' })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      status: 200,
      ok: true,
      json: async () => ({ item: null, is_playing: true }),
    }))

    const result = await fetchNowPlaying('user1')
    expect(result).toBeNull()
  })

  it('triggers refreshAccessToken on 401 and retries', async () => {
    getTokens
      .mockResolvedValueOnce({ access_token: 'expired', refresh_token: 'ref' })
      .mockResolvedValueOnce({ access_token: 'expired', refresh_token: 'ref' })

    setTokens.mockResolvedValue(undefined)

    const fetchMock = vi
      .fn()
      // First call: currently-playing → 401
      .mockResolvedValueOnce({ status: 401, ok: false })
      // Second call: refresh token endpoint
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ access_token: 'new-tok' }),
      })
      // Third call: retry currently-playing with new token → success
      .mockResolvedValueOnce({
        status: 200,
        ok: true,
        json: async () => ({
          is_playing: true,
          item: {
            name: 'Song',
            artists: [{ name: 'Artist' }],
            album: { images: [{ url: 'http://img' }] },
          },
        }),
      })

    vi.stubGlobal('fetch', fetchMock)

    const result = await fetchNowPlaying('user1')

    expect(result).not.toBeNull()
    expect(result?.track).toBe('Song')
    expect(result?.artist).toBe('Artist')
    // fetch called 3 times: expired call + refresh + retry
    expect(fetchMock).toHaveBeenCalledTimes(3)
  })
})

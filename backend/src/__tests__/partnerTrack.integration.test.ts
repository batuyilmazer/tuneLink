/**
 * Integration test for GET /partner-track.
 * Requires a running Redis at REDIS_URL (defaults to redis://localhost:6379).
 * Skipped automatically when Redis is unreachable.
 */
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { Redis } from 'ioredis'
import app from '../index.js'

const REDIS_URL = process.env.REDIS_URL ?? 'redis://localhost:6379'

let redis: Redis
let redisAvailable = false

beforeAll(async () => {
  redis = new Redis(REDIS_URL, { lazyConnect: true, enableOfflineQueue: false })
  try {
    await redis.connect()
    await redis.ping()
    redisAvailable = true
  } catch {
    await redis.quit().catch(() => {})
  }
})

afterAll(async () => {
  if (redisAvailable) {
    await redis.del('user:userA:pairId', 'user:userB:pairId', 'pair:test-pair', 'user:userB:now_playing')
    await redis.quit()
  }
})

describe('GET /partner-track (integration)', () => {
  it.skipIf(!redisAvailable)('returns playing:false when partner has no now_playing', async () => {
    await redis.set('user:userA:pairId', 'test-pair')
    await redis.set('user:userB:pairId', 'test-pair')
    await redis.set('pair:test-pair', JSON.stringify({ userA: 'userA', userB: 'userB' }))
    await redis.del('user:userB:now_playing')

    const res = await app.request('/partner-track?userId=userA')
    expect(res.status).toBe(200)
    const body = await res.json() as { playing: boolean }
    expect(body.playing).toBe(false)
  })

  it.skipIf(!redisAvailable)('returns track data when partner is playing', async () => {
    const payload = { track: 'Bohemian Rhapsody', artist: 'Queen', albumArt: 'http://img', timestamp: 1000 }
    await redis.set('user:userB:now_playing', JSON.stringify(payload), 'EX', 60)

    const res = await app.request('/partner-track?userId=userA')
    expect(res.status).toBe(200)
    const body = await res.json() as { playing: boolean; track: string }
    expect(body.playing).toBe(true)
    expect(body.track).toBe('Bohemian Rhapsody')
  })

  it.skipIf(!redisAvailable)('returns 404 when user is not paired', async () => {
    const res = await app.request('/partner-track?userId=unpaired-user')
    expect(res.status).toBe(404)
  })
})

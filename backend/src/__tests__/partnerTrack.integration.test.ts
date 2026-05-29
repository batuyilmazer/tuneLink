/**
 * Integration test for GET /group-feed.
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
    await redis.del('users:all', 'user:userA:tokens', 'user:userB:tokens', 'user:userB:displayName', 'user:userB:now_playing')
    await redis.quit()
  }
})

describe('GET /group-feed (integration)', () => {
  it.skipIf(!redisAvailable)('returns empty array when no other users exist', async () => {
    await redis.del('users:all')
    await redis.sadd('users:all', 'userA')

    const res = await app.request('/group-feed?userId=userA')
    expect(res.status).toBe(200)
    const body = await res.json() as unknown[]
    expect(body).toEqual([])
  })

  it.skipIf(!redisAvailable)('returns playing:false when other user has no now_playing', async () => {
    await redis.sadd('users:all', 'userA', 'userB')
    await redis.set('user:userB:displayName', 'User B')
    await redis.del('user:userB:now_playing')

    const res = await app.request('/group-feed?userId=userA')
    expect(res.status).toBe(200)
    const body = await res.json() as Array<{ userId: string; playing: boolean }>
    expect(body.length).toBe(1)
    expect(body[0].userId).toBe('userB')
    expect(body[0].playing).toBe(false)
  })

  it.skipIf(!redisAvailable)('returns track data when other user is playing', async () => {
    const payload = { track: 'Bohemian Rhapsody', artist: 'Queen', albumArt: 'http://img', timestamp: 1000 }
    await redis.set('user:userB:now_playing', JSON.stringify(payload), 'EX', 60)

    const res = await app.request('/group-feed?userId=userA')
    expect(res.status).toBe(200)
    const body = await res.json() as Array<{ playing: boolean; track: string }>
    expect(body[0].playing).toBe(true)
    expect(body[0].track).toBe('Bohemian Rhapsody')
  })

  it.skipIf(!redisAvailable)('excludes the requesting user from results', async () => {
    const res = await app.request('/group-feed?userId=userB')
    expect(res.status).toBe(200)
    const body = await res.json() as Array<{ userId: string }>
    expect(body.every((m) => m.userId !== 'userB')).toBe(true)
  })

  it.skipIf(!redisAvailable)('returns 400 when userId is missing', async () => {
    const res = await app.request('/group-feed')
    expect(res.status).toBe(400)
  })
})

import { Hono } from 'hono'
import { timingSafeEqual } from 'crypto'
import { redis, getNowPlaying, getLastPlayed, getUserDisplayName, getAllUserIds } from '../services/redis.js'

const debug = new Hono()

debug.get('/debug/user/:userId', async (c) => {
  const userId = c.req.param('userId')
  const secret = c.req.header('x-debug-secret') ?? ''
  const expected = process.env.DEBUG_SECRET ?? ''

  if (
    !expected ||
    Buffer.byteLength(secret, 'utf8') !== Buffer.byteLength(expected, 'utf8') ||
    !timingSafeEqual(Buffer.from(secret), Buffer.from(expected))
  ) {
    return c.json({ error: 'Unauthorized' }, 401)
  }

  const [nowPlaying, lastPlayed, displayName, hasTokens, allUserIds] = await Promise.all([
    getNowPlaying(userId),
    getLastPlayed(userId),
    getUserDisplayName(userId),
    redis.exists(`user:${userId}:tokens`),
    getAllUserIds(),
  ])

  return c.json({
    userId,
    displayName,
    hasTokens: hasTokens > 0,
    nowPlaying,
    lastPlayed,
    groupMembers: allUserIds,
  })
})

export default debug

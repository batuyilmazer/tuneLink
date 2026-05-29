import { Hono } from 'hono'
import { timingSafeEqual } from 'crypto'
import { redis, getNowPlaying, getLastPlayed, getUserPairId, getPair, getUserDisplayName } from '../services/redis.js'

const debug = new Hono()

// Temporary debug route — remove before public launch
debug.get('/debug/user/:userId', async (c) => {
  const userId = c.req.param('userId')
  const secret = c.req.header('x-debug-secret') ?? ''
  const expected = process.env.DEBUG_SECRET ?? ''

  if (
    !expected ||
    secret.length !== expected.length ||
    !timingSafeEqual(Buffer.from(secret), Buffer.from(expected))
  ) {
    return c.json({ error: 'Unauthorized' }, 401)
  }

  const [pairId, nowPlaying, lastPlayed, displayName, hasTokens] = await Promise.all([
    getUserPairId(userId),
    getNowPlaying(userId),
    getLastPlayed(userId),
    getUserDisplayName(userId),
    redis.exists(`user:${userId}:tokens`),
  ])

  let pair = null
  let partnerNowPlaying = null
  if (pairId) {
    pair = await getPair(pairId)
    if (pair) {
      const partnerId = pair.userA === userId ? pair.userB : pair.userA
      partnerNowPlaying = await getNowPlaying(partnerId)
    }
  }

  const allKeys = await redis.keys('user:*:tokens')
  const allUserIds = allKeys.map((k) => k.split(':')[1])

  return c.json({
    userId,
    displayName,
    hasTokens: hasTokens > 0,
    pairId,
    pair,
    nowPlaying,
    lastPlayed,
    partnerNowPlaying,
    allPolledUsers: allUserIds,
  })
})

export default debug

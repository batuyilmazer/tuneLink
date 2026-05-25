import { Hono } from 'hono'
import { getUserPairId, getPair, getNowPlaying, getUserDisplayName } from '../services/redis.js'

const partner = new Hono()

partner.get('/partner-track', async (c) => {
  const userId = c.req.query('userId')

  if (!userId) return c.json({ error: 'userId is required' }, 400)

  const pairId = await getUserPairId(userId)
  if (!pairId) return c.json({ error: 'User is not paired' }, 404)

  const members = await getPair(pairId)
  if (!members) return c.json({ error: 'Pair not found' }, 404)

  const partnerId = members.userA === userId ? members.userB : members.userA
  const partnerName = await getUserDisplayName(partnerId)

  const nowPlaying = await getNowPlaying(partnerId)
  if (!nowPlaying) return c.json({ playing: false, partnerName })

  return c.json({ playing: true, partnerName, ...nowPlaying })
})

export default partner

import { Hono } from 'hono'
import { randomBytes, randomUUID } from 'crypto'
import { redis, setPair, setUserPairId, getUserPairId } from '../services/redis.js'

const pair = new Hono()

function generateInviteCode(): string {
  return randomBytes(3).toString('hex').toUpperCase()
}

pair.post('/invite', async (c) => {
  const { userId } = await c.req.json<{ userId: string }>()

  if (!userId) return c.json({ error: 'userId is required' }, 400)

  const inviteCode = generateInviteCode()
  await redis.set(`invite:${inviteCode}`, userId, 'EX', 600)

  return c.json({ inviteCode })
})

pair.post('/', async (c) => {
  const { inviteCode, userId } = await c.req.json<{ inviteCode: string; userId: string }>()

  if (!inviteCode || !userId) {
    return c.json({ error: 'inviteCode and userId are required' }, 400)
  }

  const invitingUserId = await redis.get(`invite:${inviteCode}`)
  if (!invitingUserId) return c.json({ error: 'Invalid or expired invite code' }, 404)

  if (invitingUserId === userId) {
    return c.json({ error: 'Cannot pair with yourself' }, 400)
  }

  const oldPairIdA = await getUserPairId(invitingUserId)
  const oldPairIdB = await getUserPairId(userId)
  if (oldPairIdA) await redis.del(`pair:${oldPairIdA}`)
  if (oldPairIdB && oldPairIdB !== oldPairIdA) await redis.del(`pair:${oldPairIdB}`)

  const pairId = randomUUID()
  await setPair(pairId, { userA: invitingUserId, userB: userId })
  await setUserPairId(invitingUserId, pairId)
  await setUserPairId(userId, pairId)
  await redis.del(`invite:${inviteCode}`)

  return c.json({ pairId })
})

export default pair

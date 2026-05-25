import { Hono } from 'hono'
import { redis } from '../services/redis.js'

const deviceToken = new Hono()

deviceToken.post('/device-token', async (c) => {
  const { userId, deviceToken: token } = await c.req.json<{ userId: string; deviceToken: string }>()

  if (!userId || !token) {
    return c.json({ error: 'userId and deviceToken are required' }, 400)
  }

  await redis.set(`user:${userId}:device_token`, token)
  return c.json({ ok: true })
})

export default deviceToken

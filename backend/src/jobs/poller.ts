import cron from 'node-cron'
import { redis, setNowPlaying, getNowPlaying, setLastPlayed, getAllUserIds, addUserToGroup } from '../services/redis.js'
import { fetchNowPlaying } from '../services/spotify.js'
import { sendSilentPush } from '../services/apns.js'

const BUNDLE_ID = process.env.APNS_BUNDLE_ID ?? 'pizza.bira.tuneLink'

async function notifyAllOthers(exceptUserId: string): Promise<void> {
  const allUserIds = await getAllUserIds()
  await Promise.all(
    allUserIds
      .filter((id) => id !== exceptUserId)
      .map(async (id) => {
        const deviceToken = await redis.get(`user:${id}:device_token`)
        if (deviceToken) {
          await sendSilentPush(deviceToken, BUNDLE_ID)
        }
      }),
  )
}

async function pollAllUsers(): Promise<void> {
  let cursor = '0'

  do {
    const [nextCursor, keys] = await redis.scan(cursor, 'MATCH', 'user:*:tokens', 'COUNT', 100)
    cursor = nextCursor

    for (const key of keys) {
      const userId = key.split(':')[1]
      if (!userId) continue

      await addUserToGroup(userId)

      try {
        const previous = await getNowPlaying(userId)
        const nowPlaying = await fetchNowPlaying(userId)

        if (nowPlaying) {
          await setNowPlaying(userId, nowPlaying)
          await setLastPlayed(userId, nowPlaying)

          if (previous?.track !== nowPlaying.track) {
            await notifyAllOthers(userId)
          }
        } else if (previous) {
          await redis.del(`user:${userId}:now_playing`)
          await notifyAllOthers(userId)
        }
      } catch (err) {
        console.error(`[poller] error polling user ${userId}:`, err)
      }
    }
  } while (cursor !== '0')
}

export function startPoller(): void {
  cron.schedule('*/30 * * * * *', () => {
    pollAllUsers().catch(() => {})
  })
}

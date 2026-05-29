import cron from 'node-cron'
import { redis, setNowPlaying, getNowPlaying, setLastPlayed, getUserPairId, getPair } from '../services/redis.js'
import { fetchNowPlaying } from '../services/spotify.js'
import { sendSilentPush } from '../services/apns.js'

const BUNDLE_ID = process.env.APNS_BUNDLE_ID ?? 'pizza.bira.tuneLink'

async function pollAllUsers(): Promise<void> {
  let cursor = '0'

  do {
    const [nextCursor, keys] = await redis.scan(cursor, 'MATCH', 'user:*:tokens', 'COUNT', 100)
    cursor = nextCursor

    for (const key of keys) {
      const userId = key.split(':')[1]
      if (!userId) continue

      try {
        const previous = await getNowPlaying(userId)
        const nowPlaying = await fetchNowPlaying(userId)

        if (nowPlaying) {
          await setNowPlaying(userId, nowPlaying)
          await setLastPlayed(userId, nowPlaying)

          const trackChanged = previous?.track !== nowPlaying.track

          if (trackChanged) {
            const pairId = await getUserPairId(userId)
            if (pairId) {
              const members = await getPair(pairId)
              if (members) {
                const partnerId = members.userA === userId ? members.userB : members.userA
                const partnerDeviceToken = await redis.get(`user:${partnerId}:device_token`)
                if (partnerDeviceToken) {
                  await sendSilentPush(partnerDeviceToken, BUNDLE_ID)
                }
              }
            }
          }
        } else if (previous) {
          // User stopped listening — clear stale key immediately and notify partner
          await redis.del(`user:${userId}:now_playing`)
          const pairId = await getUserPairId(userId)
          if (pairId) {
            const members = await getPair(pairId)
            if (members) {
              const partnerId = members.userA === userId ? members.userB : members.userA
              const partnerDeviceToken = await redis.get(`user:${partnerId}:device_token`)
              if (partnerDeviceToken) {
                await sendSilentPush(partnerDeviceToken, BUNDLE_ID)
              }
            }
          }
        }
      } catch (err) {
        console.error(`[poller] error polling user ${userId}:`, err)
      }
    }
  } while (cursor !== '0')
}

export function startPoller(): void {
  cron.schedule('*/30 * * * * *', () => {
    pollAllUsers().catch(() => {
      // swallow unhandled rejection to keep the cron alive
    })
  })
}

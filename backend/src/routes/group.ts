import { Hono } from 'hono'
import { getAllUserIds, getNowPlaying, getLastPlayed, getUserDisplayName } from '../services/redis.js'

const group = new Hono()

group.get('/group-feed', async (c) => {
  const userId = c.req.query('userId')
  if (!userId) return c.json({ error: 'userId is required' }, 400)

  const allUserIds = await getAllUserIds()
  if (!allUserIds.includes(userId)) {
    return c.json({ error: 'Unauthorized' }, 403)
  }
  const otherUserIds = allUserIds.filter((id) => id !== userId)

  const feed = await Promise.all(
    otherUserIds.map(async (uid) => {
      const displayName = await getUserDisplayName(uid)
      const nowPlaying = await getNowPlaying(uid)

      if (nowPlaying) {
        return {
          userId: uid,
          displayName: displayName ?? uid,
          playing: true,
          track: nowPlaying.track,
          artist: nowPlaying.artist,
          albumArt: nowPlaying.albumArt,
          timestamp: nowPlaying.timestamp,
          lastTrack: null,
          lastArtist: null,
          lastAlbumArt: null,
          lastPlayedAt: null,
        }
      }

      const lastPlayed = await getLastPlayed(uid)
      return {
        userId: uid,
        displayName: displayName ?? uid,
        playing: false,
        track: null,
        artist: null,
        albumArt: null,
        timestamp: null,
        lastTrack: lastPlayed?.track ?? null,
        lastArtist: lastPlayed?.artist ?? null,
        lastAlbumArt: lastPlayed?.albumArt ?? null,
        lastPlayedAt: lastPlayed?.timestamp ?? null,
      }
    }),
  )

  return c.json(feed)
})

export default group

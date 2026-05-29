import { Hono } from 'hono'
import { getAllUserIds, getNowPlaying, getLastPlayed, getUserDisplayName, getSessionToken } from '../services/redis.js'

const group = new Hono()

group.get('/group-feed', async (c) => {
  const userId = c.req.query('userId')
  if (!userId) return c.json({ error: 'userId is required' }, 400)

  const bearer = c.req.header('Authorization')?.replace(/^Bearer\s+/i, '')
  if (!bearer) return c.json({ error: 'Unauthorized' }, 401)

  const stored = await getSessionToken(userId)
  if (!stored || stored !== bearer) return c.json({ error: 'Unauthorized' }, 401)

  const allUserIds = await getAllUserIds()
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

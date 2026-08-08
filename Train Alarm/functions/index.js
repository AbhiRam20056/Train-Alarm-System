const { onRequest } = require('firebase-functions/v2/https');
const axios = require('axios');

// In-memory cache: cacheKey → { data, expiresAt }
const cache = new Map();
const CACHE_TTL_MS = 60 * 1000; // 1 minute

exports.railradar = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'GET') {
    res.status(405).json({ success: false, error: 'Method not allowed' });
    return;
  }

  const path = req.query.path;
  if (!path || !path.startsWith('/')) {
    res.status(400).json({ success: false, error: 'Missing or invalid ?path= parameter' });
    return;
  }

  // Build cache key
  const forwardParams = { ...req.query };
  delete forwardParams.path;
  const cacheKey = path + JSON.stringify(forwardParams);

  const cached = cache.get(cacheKey);
  if (cached && Date.now() < cached.expiresAt) {
    res.set('X-Cache', 'HIT');
    res.json(cached.data);
    return;
  }

  const apiKey = process.env.RAILRADAR_API_KEY;
  if (!apiKey) {
    res.status(500).json({ success: false, error: 'API key not configured' });
    return;
  }

  const BASE_URL = 'https://api.railradar.in/v1';
  const url = `${BASE_URL}${path}`;

  try {
    const upstream = await axios.get(url, {
      params: forwardParams,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        Accept: 'application/json',
      },
      timeout: 10000,
    });

    cache.set(cacheKey, { data: upstream.data, expiresAt: Date.now() + CACHE_TTL_MS });

    res.set('X-Cache', 'MISS');
    res.json(upstream.data);
  } catch (err) {
    const status = err.response?.status ?? 503;
    const message = err.response?.data ?? err.message;
    res.status(status).json({ success: false, error: message, upstreamStatus: status });
  }
});

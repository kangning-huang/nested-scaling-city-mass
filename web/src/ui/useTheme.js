import { useState, useEffect } from 'react'

const LIGHT_COLORS = {
  axis: '#ebe7e1',
  grid: '#f0ede9',
  tickText: '#9a948e',
  labelText: '#6b6560',
  emptyText: '#9a948e',
  zeroLine: '#d0cdc8',
}

const DARK_COLORS = {
  axis: '#3a3a42',
  grid: '#2e2e36',
  tickText: '#7a756f',
  labelText: '#8a857f',
  emptyText: '#6b6560',
  zeroLine: '#4a4a52',
}

export function useTheme() {
  const [isDark, setIsDark] = useState(
    () => window.matchMedia('(prefers-color-scheme: dark)').matches
  )

  useEffect(() => {
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    const handler = (e) => setIsDark(e.matches)
    mq.addEventListener('change', handler)
    return () => mq.removeEventListener('change', handler)
  }, [])

  return { isDark, chartColors: isDark ? DARK_COLORS : LIGHT_COLORS }
}

#!/usr/bin/env node
/**
 * Fix countries.geojson by downloading proper Natural Earth 10m countries
 * and extracting ISO_A3 → iso3, NAME → name properties.
 *
 * The existing countries.geojson has null iso3/name for all features.
 * This script downloads the full NE dataset, extracts needed properties,
 * and writes a corrected GeoJSON.
 */

import { writeFileSync, readFileSync } from 'fs'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

// Use 50m for smaller file size (~700KB vs 12MB for 10m) — sufficient for interactive map
const NE_URL = 'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson'
const OUT_PATH = join(__dirname, '..', 'public', 'webdata', 'countries.geojson')
const CITY_INDEX_PATH = join(__dirname, '..', 'public', 'webdata', 'index', 'country_to_cities.json')

async function main() {
  console.log('Downloading Natural Earth 10m countries...')
  const res = await fetch(NE_URL)
  if (!res.ok) throw new Error(`Failed to download: ${res.status}`)
  const ne = await res.json()
  console.log(`Downloaded ${ne.features.length} features`)

  // Extract iso3 and name, using ISO_A3_EH as fallback when ISO_A3 is -99
  const features = ne.features.map(f => {
    const p = f.properties || {}
    let iso3 = p.ISO_A3
    if (!iso3 || iso3 === '-99') iso3 = p.ISO_A3_EH
    if (!iso3 || iso3 === '-99') iso3 = p.ADM0_A3
    const name = p.NAME || p.NAME_EN || p.ADMIN || null

    return {
      type: 'Feature',
      properties: { iso3, name },
      geometry: f.geometry
    }
  })

  const out = { type: 'FeatureCollection', features }

  // Validate against country_to_cities.json
  const cityIndex = JSON.parse(readFileSync(CITY_INDEX_PATH, 'utf8'))
  const neededISOs = Object.keys(cityIndex)
  const availableISOs = new Set(features.map(f => f.properties.iso3))
  const missing = neededISOs.filter(iso => !availableISOs.has(iso))

  console.log(`Output features: ${features.length}`)
  console.log(`Needed ISOs: ${neededISOs.length}`)
  console.log(`Found: ${neededISOs.length - missing.length}/${neededISOs.length}`)

  if (missing.length > 0) {
    console.warn(`Missing ISOs: ${missing.join(', ')}`)
  }

  // Check for null values
  const nullIso = features.filter(f => !f.properties.iso3).length
  const nullName = features.filter(f => !f.properties.name).length
  console.log(`Null iso3: ${nullIso}, Null name: ${nullName}`)

  writeFileSync(OUT_PATH, JSON.stringify(out))
  console.log(`Written to ${OUT_PATH}`)
  console.log('Done!')
}

main().catch(err => { console.error(err); process.exit(1) })

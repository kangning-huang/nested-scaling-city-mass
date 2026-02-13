import React, { useState } from 'react'
import MapView from './MapView.jsx'
import CityPanel from './CityPanel.jsx'
import NeighborhoodPanel from './NeighborhoodPanel.jsx'

const App = () => {
  const [scope, setScope] = useState({ level: 'global' })
  const [metric, setMetric] = useState('mass')
  const [cityName, setCityName] = useState(null)
  const [countryName, setCountryName] = useState(null)

  const onSelectCountry = (iso3, name) => {
    setScope({ level: 'country', iso: iso3 })
    setCountryName(name || iso3)
    setCityName(null)
  }
  const onSelectCity = (cityId, name) => {
    setScope((s) => ({ level: 'city', iso: s.iso, cityId }))
    setCityName(name || `City ${cityId}`)
  }
  const onReset = () => {
    setScope({ level: 'global' })
    setCityName(null)
    setCountryName(null)
  }
  const onResetToCountry = () => {
    setScope((s) => ({ level: 'country', iso: s.iso }))
    setCityName(null)
  }

  return (
    <div className="app-layout">
      <div className="panel panel-left">
        <div className="site-header">
          <div className="site-title">Nested Scaling of Urban Material Stocks</div>
          <div className="site-subtitle">Population-mass scaling across cities and neighborhoods</div>
          <div className="breadcrumbs">
            <span className={`crumb${scope.level === 'global' ? ' active' : ''}`} onClick={onReset}>Global</span>
            {scope.level !== 'global' && (
              <>
                <span className="sep">/</span>
                <span className={`crumb${scope.level === 'country' ? ' active' : ''}`} onClick={onResetToCountry}>
                  {countryName || scope.iso}
                </span>
              </>
            )}
            {scope.level === 'city' && (
              <>
                <span className="sep">/</span>
                <span className="crumb active">{cityName}</span>
              </>
            )}
          </div>
        </div>
        <div className="controls-bar">
          <span className="control-label">Map metric</span>
          <div className="toggle-group">
            <button onClick={() => setMetric('mass')} disabled={metric === 'mass'}>Built Mass</button>
            <button onClick={() => setMetric('pop')} disabled={metric === 'pop'}>Population</button>
          </div>
        </div>
        <div className="section">
          <CityPanel scope={scope} onSelectCity={onSelectCity} countryName={countryName} />
        </div>
      </div>

      <MapView scope={scope} metric={metric} onSelectCountry={onSelectCountry} onSelectCity={onSelectCity} />

      <div className="panel panel-right">
        <div className="section">
          <NeighborhoodPanel scope={scope} cityName={cityName} countryName={countryName} />
        </div>
      </div>
    </div>
  )
}

export default App

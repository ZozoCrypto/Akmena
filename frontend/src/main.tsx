import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import { OnchainProviders } from './OnchainProviders.tsx'
import '@coinbase/onchainkit/styles.css'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <OnchainProviders>
      <App />
    </OnchainProviders>
  </React.StrictMode>,
)

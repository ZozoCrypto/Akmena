import "./index.css";
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import { OnchainProviders } from './OnchainProviders.tsx'
import { AkmenaStateProvider } from './state/AkmenaStateProvider.tsx'
import { ApprovalRequestProvider } from './features/approvals/ApprovalRequestProvider.tsx'
import '@coinbase/onchainkit/styles.css'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <OnchainProviders>
      <AkmenaStateProvider>
        <ApprovalRequestProvider>
          <App />
        </ApprovalRequestProvider>
      </AkmenaStateProvider>
    </OnchainProviders>
  </React.StrictMode>,
)

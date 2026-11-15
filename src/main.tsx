import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import './theme.css'
import App from './App'
import { usePreferences } from './core/preferences/preferences'

const fonts = document.querySelector<HTMLLinkElement>('#bilimyol-fonts')
if (fonts) {
  const applyFonts = () => { fonts.media = 'all' }
  if (fonts.sheet) applyFonts()
  else fonts.addEventListener('load', applyFonts, { once: true })
}

async function mount() {
  const { language, setLanguage } = usePreferences.getState()
  if (language === 'ru') {
    try { await setLanguage(language, false) }
    catch { await setLanguage('uz', false) }
  }
  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      <App />
    </StrictMode>,
  )
}
void mount()

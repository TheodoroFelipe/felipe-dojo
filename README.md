# 武 Showcase Dojo · Felipe

Aplicação PWA gamificada para acompanhamento de treino, dieta e evolução física, com tema dojo japonês.

## ⛩ Funcionalidades

- **Acompanhamento diário** de treino (6 dias) e dieta (5 refeições)
- **Personal Records (PRs)** automáticos por exercício
- **Sistema de XP e faixas** (Branca → Amarela → Verde → Azul → Marrom → Preta → Shihan)
- **12 medalhas** desbloqueáveis
- **Streak diário** com contagem de dias consecutivos
- **Gráfico de evolução** corporal (peso, cintura, peito, braço, coxa)
- **Export/Import JSON** com filtro por período (semana, mês, últimos 7/30 dias, tudo)
- **Relatórios formatados** semanal e mensal para enviar ao treinador
- **Cards visuais PNG** para Instagram (Feed 1:1 e Stories 9:16)
- **Notificações de lembrete** configuráveis (treino, 5 refeições, pesagem semanal)
- **PWA instalável** com ícone na tela inicial
- **Funciona 100% offline** após primeira abertura
- **Tema claro estilo japonês esportivo** (anime/manga vibe)

## 📁 Estrutura do projeto

```
dojo-pwa/
├── index.html              # App principal (todo o código)
├── manifest.json           # Manifest do PWA
├── sw.js                   # Service Worker (cache offline)
├── vercel.json             # Config de headers para Vercel
├── icon-192.png            # Ícone 192×192
├── icon-512.png            # Ícone 512×512
├── icon-192-maskable.png   # Maskable Android
├── icon-512-maskable.png   # Maskable Android
├── apple-touch-icon.png    # iOS 180×180
└── favicon-32.png          # Favicon
```

## 🚀 Deploy no Vercel

### Opção 1 — Drag & drop (mais fácil)

1. Acesse https://vercel.com/new
2. Faça login com GitHub/Google
3. Arraste a pasta inteira `dojo-pwa/` para a área de upload
4. Clique em **Deploy**
5. Em segundos você terá uma URL tipo `dojo-pwa-xxxxx.vercel.app`

### Opção 2 — Vercel CLI

```bash
# Instale a CLI uma vez
npm install -g vercel

# Dentro da pasta dojo-pwa
cd dojo-pwa
vercel

# Siga o assistente. Use as configurações padrão.
# Para produção:
vercel --prod
```

### Opção 3 — GitHub + auto-deploy

1. Crie um repositório no GitHub e suba os arquivos
2. No Vercel, clique em **New Project** → conecte o repo
3. Mantenha as configurações padrão e Deploy
4. Cada `git push` faz deploy automático

## 📲 Como instalar como app no celular

### Android (Chrome)
1. Abra a URL do Vercel no Chrome
2. Toque no menu (três pontos)
3. **"Instalar app"** ou **"Adicionar à tela inicial"**
4. Pronto — vai virar ícone como qualquer app

### iPhone/iPad (Safari)
1. Abra a URL do Vercel **no Safari** (precisa ser Safari)
2. Toque em **Compartilhar** (quadrado com seta para cima)
3. Role e toque em **"Adicionar à Tela de Início"**
4. Confirme

### Desktop (Chrome/Edge)
- Aparece um ícone de instalação na barra de endereço, à direita

## 💾 Sobre os dados

- **Tudo é salvo localmente** no navegador via `localStorage`
- **Não há servidor**, login ou sincronização entre dispositivos
- Limpar cache do navegador apaga os dados — use **Export JSON** regularmente como backup
- Para "migrar" entre dispositivos: exporte JSON em um, importe no outro

## 🔔 Sobre as notificações

As notificações funcionam quando o app está aberto ou foi aberto recentemente (porque é PWA sem servidor próprio). Para garantir lembretes 100% confiáveis, **use também o app de Lembretes/Alarmes nativo do celular como backup** com os mesmos horários.

## 🔧 Atualizando o app

Se você modificar o código e fizer redeploy:
1. Bump a versão `CACHE_NAME` no `sw.js` (ex: `dojo-v1.0.1` → `dojo-v1.0.2`)
2. Os usuários receberão a nova versão automaticamente na próxima abertura

## 📜 Licença

Uso pessoal · Felipe XSHOWCASE TEAM

---

道 場 · "千里の道も一歩から"
*Uma jornada de mil milhas começa com um único passo.*

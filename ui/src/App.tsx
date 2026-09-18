/* LXR-CRAFT — the book | © 2026 iBoss21 / LXRCore
   open / update { payload: { kind, station, kindLabel, recipes[], trades[], specials[], slots, changeCost, made, queue, maxQueue }, images } · queue { payload | null } · close
   callbacks: start { id, times } · stop · specialise { trade } · close */
import { useEffect, useMemo, useState } from 'react';
import { onMessage, applyChrome, makeT, post, money, pad, type Msg } from './nui';

type Line = { name: string; label: string; need?: number; have?: number; amount?: number };
type Recipe = { id: string; kind: string; trade: string; level: number; xp: number; seconds: number; special: boolean; tool?: { name: string; label: string; have: boolean }; input: Line[]; output: Line[]; may: boolean; why?: string; times: number; label: string };
type Trade = { id: string; level: number; max: number; xp: number; progress: number; special: boolean };
type Queue = { id: string; left: number; total: number; seconds: number; label: string; endsAt?: number } | null;
type Book = { kind: string; station?: { id: string; label: string }; kindLabel: string; recipes: Recipe[]; trades: Trade[]; specials: string[]; slots: number; changeCost: number; made: number; queue: Queue; maxQueue: number };

export function App() {
  const [B, setB] = useState<Book | null>(null);
  const [L, setL] = useState<Record<string, string>>({});
  const [images, setImages] = useState('');
  const [q, setQ] = useState('');
  const [only, setOnly] = useState(false);
  const [trade, setTrade] = useState('all');
  const [pick, setPick] = useState<string | null>(null);
  const [times, setTimes] = useState(1);
  const [queue, setQueue] = useState<Queue>(null);
  const [tick, setTick] = useState(0);
  const [busy, setBusy] = useState(false);
  const t = makeT(L);

  useEffect(() => onMessage((m: Msg) => {
    applyChrome(m);
    if (m.locale) setL(m.locale);
    if (m.images) setImages(m.images);
    if (m.action === 'open') { setB(m.payload); setQueue(m.payload?.queue || null); setPick(null); setQ(''); setOnly(false); setTrade('all'); setTimes(1); }
    if (m.action === 'update') { setB(m.payload); setQueue(m.payload?.queue || null); }
    if (m.action === 'queue') setQueue(m.payload || null);
    if (m.action === 'close') setB(null);
  }), []);
  useEffect(() => { const k = (e: KeyboardEvent) => { if (e.key === 'Escape' || (e.key === 'Backspace' && (e.target as HTMLElement).tagName !== 'INPUT')) post('close'); }; document.addEventListener('keydown', k); return () => document.removeEventListener('keydown', k); }, []);
  useEffect(() => { if (!queue) return; const i = setInterval(() => setTick((x) => x + 1), 250); return () => clearInterval(i); }, [queue]);

  const img = (name: string) => images + name + '.png';
  const trades = useMemo(() => { const s = new Set<string>(); B?.recipes.forEach((r) => s.add(r.trade)); return [...s].sort(); }, [B]);
  const shown = useMemo(() => { if (!B) return []; const n = q.trim().toLowerCase(); return B.recipes.filter((r) => (trade === 'all' || r.trade === trade) && (!only || (r.may && r.times > 0 && (!r.tool || r.tool.have))) && (!n || r.label.toLowerCase().includes(n) || r.input.some((l) => l.label.toLowerCase().includes(n)))); }, [B, q, only, trade]);
  const recipe = useMemo(() => B && pick ? B.recipes.find((r) => r.id === pick) || null : null, [B, pick]);
  const start = async () => { if (!recipe || busy) return; setBusy(true); await post('start', { id: recipe.id, times }); setBusy(false); };

  if (!B) return null;
  const tradeOf = (id: string) => B.trades.find((x) => x.id === id);
  const canStart = recipe && recipe.may && recipe.times > 0 && (!recipe.tool || recipe.tool.have) && !queue;
  const qLeft = queue && queue.endsAt ? Math.max(0, queue.endsAt - Date.now() / 1000) : 0;
  const qPct = queue && queue.endsAt ? Math.max(0, Math.min(100, (1 - qLeft / queue.seconds) * 100)) : 0;
  void tick;

  return (
    <div id="app">
      <header className="cr-top lxr-hit">
        <div className="cr-brand"><img className="cr-logo" src="img/lxrcore-logo.png" alt="" /><div><span className="lxr-mono lxr-t-ash">{t('ui.kicker')} · {B.kindLabel}</span><h1 className="lxr-cut cr-title">{B.station ? B.station.label : t('ui.hands_only')}</h1></div></div>
        <span className="lxr-grow" />
        <span className="lxr-mono lxr-t-smoke">{B.made} {t('ui.made')}</span>
        <span className="cr-hint lxr-mono lxr-t-smoke"><span className="lxr-key">Esc</span> {t('ui.hint_close')}</span>
      </header>

      {/* trades */}
      <aside className="cr-trades lxr-hit">
        <div className="cr-side__head lxr-mono lxr-t-ash">{t('ui.trades')}<span className="lxr-grow" /><span className="lxr-t-smoke">{t('ui.slots', { n: B.slots })}</span></div>
        {B.trades.map((tr) => (
          <div key={tr.id} className={'cr-trade' + (tr.special ? ' is-master' : '')}>
            <div className="cr-trade__row"><span className="cr-trade__name">{t('trade.' + tr.id)}</span><span className="lxr-grow" /><span className="lxr-mono lxr-t-smoke">{t('ui.level')} {tr.level}/{tr.max}</span></div>
            <div className="lxr-meter"><div className="lxr-meter-fill" style={{ width: Math.round(tr.progress * 100) + '%' }} /></div>
            <div className="cr-trade__row"><span className="lxr-mono lxr-t-smoke">{tr.xp} {t('ui.xp')}</span><span className="lxr-grow" />{B.slots > 0 && <button className={'lxr-chip' + (tr.special ? ' is-on' : '')} aria-pressed={tr.special} onClick={() => post('specialise', { trade: tr.id })}>{tr.special ? t('ui.master') : t('ui.specialise')}</button>}</div>
          </div>
        ))}
        {B.slots > 0 && B.changeCost > 0 && <div className="cr-side__foot lxr-mono lxr-t-smoke">{t('ui.cost', { amount: money(B.changeCost) })}</div>}
      </aside>

      {/* recipes */}
      <section className="cr-list lxr-hit">
        <div className="cr-list__head lxr-rule-b">
          <button className="lxr-chip" aria-pressed={trade === 'all'} onClick={() => setTrade('all')}>{t('ui.all')}</button>
          {trades.map((x) => <button key={x} className="lxr-chip" aria-pressed={trade === x} onClick={() => setTrade(x)}>{t('trade.' + x)}</button>)}
          <span className="lxr-grow" />
          <button className="lxr-chip" aria-pressed={only} onClick={() => setOnly(!only)}>{t('ui.can_make')}</button>
          <input className="lxr-input cr-search" placeholder={t('ui.search')} value={q} onChange={(e) => setQ(e.target.value)} />
        </div>
        <div className="cr-rows">
          {shown.map((r, i) => {
            const ok = r.may && r.times > 0 && (!r.tool || r.tool.have);
            return (
              <div key={r.id} className={'cr-recipe' + (pick === r.id ? ' is-on' : '') + (ok ? '' : ' is-off') + (r.special ? ' is-special' : '')} onClick={() => { setPick(r.id); setTimes(Math.max(1, Math.min(r.times || 1, times))); }}>
                <span className="lxr-row-index">{pad(i + 1)}</span>
                <img className="cr-recipe__img" src={img(r.output[0].name)} alt="" onError={(e) => { (e.target as HTMLImageElement).style.visibility = 'hidden'; }} />
                <div className="cr-recipe__body">
                  <div className="cr-recipe__name">{r.output.map((o) => `${o.amount}× ${o.label}`).join(' · ')}</div>
                  <div className="cr-recipe__meta lxr-mono">{t('trade.' + r.trade)} {r.level} · {t('ui.seconds', { n: r.seconds })} · +{r.xp} {t('ui.xp')}{r.special ? ' · ' + t('ui.special') : ''}{r.tool ? ' · ' + r.tool.label : ''}</div>
                </div>
                <span className="lxr-grow" />
                <span className={'cr-recipe__times lxr-mono' + (ok ? '' : ' is-bad')}>{!r.may ? t('error.' + r.why) : r.tool && !r.tool.have ? t('error.no_tool', { label: r.tool.label }) : r.times > 0 ? '×' + r.times : t('ui.short')}</span>
              </div>
            );
          })}
        </div>
      </section>

      {/* the picked recipe */}
      <aside className={'cr-detail lxr-hit' + (recipe ? '' : ' is-empty')}>
        {!recipe && !queue && <div className="cr-empty lxr-t-smoke">{t('ui.make')} —</div>}
        {recipe && (
          <>
            <div className="cr-detail__head"><img className="cr-detail__img" src={img(recipe.output[0].name)} alt="" onError={(e) => { (e.target as HTMLImageElement).style.visibility = 'hidden'; }} /><div><div className="cr-detail__name lxr-cut">{recipe.label}</div><div className="lxr-mono lxr-t-smoke">{t('trade.' + recipe.trade)} · {t('ui.level')} {recipe.level} · {tradeOf(recipe.trade)?.level ?? 1} {t('ui.have')}</div></div></div>
            <div className="cr-block">
              <div className="lxr-mono lxr-t-ash cr-block__k">{t('ui.needs')}</div>
              {recipe.input.map((l) => <div key={l.name} className={'cr-line' + ((l.have || 0) >= (l.need || 0) * times ? '' : ' is-bad')}><img src={img(l.name)} alt="" onError={(e) => { (e.target as HTMLImageElement).style.visibility = 'hidden'; }} /><span>{l.label}</span><span className="lxr-grow" /><span className="lxr-mono">{l.have} / {(l.need || 0) * times}</span></div>)}
              {recipe.tool && <div className={'cr-line' + (recipe.tool.have ? '' : ' is-bad')}><img src={img(recipe.tool.name)} alt="" onError={(e) => { (e.target as HTMLImageElement).style.visibility = 'hidden'; }} /><span>{recipe.tool.label}</span><span className="lxr-grow" /><span className="lxr-mono">{t('ui.tool')}</span></div>}
            </div>
            <div className="cr-block">
              <div className="lxr-mono lxr-t-ash cr-block__k">{t('ui.gives')}</div>
              {recipe.output.map((l) => <div key={l.name} className="cr-line"><img src={img(l.name)} alt="" onError={(e) => { (e.target as HTMLImageElement).style.visibility = 'hidden'; }} /><span>{l.label}</span><span className="lxr-grow" /><span className="lxr-mono">×{(l.amount || 0) * times}</span></div>)}
              <div className="lxr-mono lxr-t-smoke">{t('ui.time')} {recipe.seconds * times}s · +{recipe.xp * times} {t('ui.xp')}</div>
            </div>
            {!queue && (
              <div className="cr-block cr-make">
                <div className="cr-times"><button className="lxr-btn lxr-btn-ghost lxr-btn-sm" onClick={() => setTimes(Math.max(1, times - 1))}>−</button><span className="lxr-num">{times}</span><button className="lxr-btn lxr-btn-ghost lxr-btn-sm" onClick={() => setTimes(Math.min(B.maxQueue, Math.max(1, recipe.times), times + 1))}>+</button><button className="lxr-btn lxr-btn-ghost lxr-btn-sm" onClick={() => setTimes(Math.min(B.maxQueue, Math.max(1, recipe.times)))}>max</button></div>
                <button className="lxr-btn" disabled={!canStart || busy} onClick={start}>{times > 1 ? t('ui.make_n', { n: times }) : t('ui.make')}</button>
              </div>
            )}
          </>
        )}
        {queue && (
          <div className="cr-block cr-queue">
            <div className="lxr-mono lxr-t-ash cr-block__k">{t('ui.working')}</div>
            <div className="cr-queue__name lxr-cut">{queue.label}</div>
            <div className="lxr-mono lxr-t-smoke">{queue.total - queue.left + 1} {t('ui.of')} {queue.total} · {Math.ceil(qLeft)}s</div>
            <div className="lxr-meter"><div className="lxr-meter-fill" style={{ width: qPct + '%' }} /></div>
            <button className="lxr-btn lxr-btn-ghost lxr-btn-sm" onClick={() => post('stop')}>{t('ui.stop')}</button>
          </div>
        )}
      </aside>
    </div>
  );
}

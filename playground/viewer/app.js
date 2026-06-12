(function () {
  const state = {
    artifact: null,
    bars: [],
    minPrice: 0,
    maxPrice: 0,
    fitPadding: 0.04,
    artifactExplanation: null,
    externalExplanation: null,
    themePreference: "system",
    effectiveTheme: "light",
    themeMediaQuery: null
  };

  const THEME_STORAGE_KEY = "mohy_playground_theme";

  const palettes = {
    light: {
      canvasBg: "#ffffff",
      emptyMessage: "#475569",
      grid: "#e2e8f0",
      axis: "#64748b",
      candleBull: "#22c55e",
      candleBear: "#ef4444",
      candleWick: "#334155",
      elementPeak: "#1d4ed8",
      elementValley: "#0ea5e9",
      legBull: "#16a34a",
      legBear: "#dc2626",
      swing3Label: "#7c3aed",
      impulse: "#0f766e",
      correctionForming: "#d97706",
      correctionConfirmed: "#1d4ed8",
      correctionInvalid: "#dc2626",
      continuation: "#111827",
      tradeSetupEligible: "#2563eb",
      tradeSetupWaiting: "#d97706",
      tradeSetupInvalid: "#94a3b8",
      tradeSetupStop: "#dc2626",
      tradeSetupTarget: "#059669"
    },
    dark: {
      canvasBg: "#020617",
      emptyMessage: "#cbd5e1",
      grid: "#1e293b",
      axis: "#94a3b8",
      candleBull: "#22c55e",
      candleBear: "#f87171",
      candleWick: "#94a3b8",
      elementPeak: "#60a5fa",
      elementValley: "#22d3ee",
      legBull: "#4ade80",
      legBear: "#f87171",
      swing3Label: "#c084fc",
      impulse: "#2dd4bf",
      correctionForming: "#f59e0b",
      correctionConfirmed: "#60a5fa",
      correctionInvalid: "#f87171",
      continuation: "#e2e8f0",
      tradeSetupEligible: "#60a5fa",
      tradeSetupWaiting: "#fbbf24",
      tradeSetupInvalid: "#94a3b8",
      tradeSetupStop: "#f87171",
      tradeSetupTarget: "#34d399"
    }
  };

  const ui = {
    exampleSelect: document.getElementById("exampleSelect"),
    loadExampleBtn: document.getElementById("loadExampleBtn"),
    artifactFile: document.getElementById("artifactFile"),
    explainFile: document.getElementById("explainFile"),
    clearExplainBtn: document.getElementById("clearExplainBtn"),
    themeSelect: document.getElementById("themeSelect"),
    fitBtn: document.getElementById("fitBtn"),
    meta: document.getElementById("meta"),
    summary: document.getElementById("summary"),
    explainTitle: document.getElementById("explainTitle"),
    explainSource: document.getElementById("explainSource"),
    explainContent: document.getElementById("explainContent"),
    canvas: document.getElementById("chartCanvas"),
    layerCandles: document.getElementById("layerCandles"),
    layerElements: document.getElementById("layerElements"),
    layerLegs: document.getElementById("layerLegs"),
    layerSwing3: document.getElementById("layerSwing3"),
    layerImpulse: document.getElementById("layerImpulse"),
    layerCorrection: document.getElementById("layerCorrection"),
    layerContinuation: document.getElementById("layerContinuation"),
    layerTradeSetup: document.getElementById("layerTradeSetup")
  };

  function getExamples() {
    if (!window.MOHY_PLAYGROUND_EXAMPLES) return {};
    return window.MOHY_PLAYGROUND_EXAMPLES;
  }

  function sanitizeThemePreference(value) {
    const v = String(value || "").toLowerCase();
    if (v === "light" || v === "dark" || v === "system") return v;
    return "system";
  }

  function getSystemTheme() {
    if (!window.matchMedia) return "light";
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }

  function resolveEffectiveTheme(pref) {
    return pref === "system" ? getSystemTheme() : pref;
  }

  function getPalette() {
    return state.effectiveTheme === "dark" ? palettes.dark : palettes.light;
  }

  function loadThemePreference() {
    try {
      return sanitizeThemePreference(window.localStorage.getItem(THEME_STORAGE_KEY));
    } catch (e) {
      return "system";
    }
  }

  function saveThemePreference(pref) {
    try {
      window.localStorage.setItem(THEME_STORAGE_KEY, pref);
    } catch (e) {
      // Ignore storage failures (private/incognito restrictions).
    }
  }

  function applyTheme(preference) {
    const pref = sanitizeThemePreference(preference);
    state.themePreference = pref;
    state.effectiveTheme = resolveEffectiveTheme(pref);
    document.documentElement.setAttribute("data-theme", state.effectiveTheme);
    if (ui.themeSelect && ui.themeSelect.value !== pref) {
      ui.themeSelect.value = pref;
    }
    draw();
  }

  function toDateMs(value) {
    if (!value) return NaN;
    const t = Date.parse(value);
    return Number.isFinite(t) ? t : NaN;
  }

  function clone(v) {
    return JSON.parse(JSON.stringify(v));
  }

  function normNumber(v, fallback) {
    const n = Number(v);
    return Number.isFinite(n) ? n : fallback;
  }

  function normalizeArtifact(raw) {
    const artifact = clone(raw || {});
    artifact.candles = Array.isArray(artifact.candles) ? artifact.candles : [];
    artifact.elements = Array.isArray(artifact.elements) ? artifact.elements : [];
    artifact.legs = Array.isArray(artifact.legs) ? artifact.legs : [];
    artifact.swings3 = Array.isArray(artifact.swings3) ? artifact.swings3 : [];
    artifact.potential_impulses = Array.isArray(artifact.potential_impulses) ? artifact.potential_impulses : [];
    artifact.potential_corrections = Array.isArray(artifact.potential_corrections) ? artifact.potential_corrections : [];
    artifact.potential_continuation_signals = Array.isArray(artifact.potential_continuation_signals)
      ? artifact.potential_continuation_signals
      : [];
    artifact.trade_setup_plans = Array.isArray(artifact.trade_setup_plans)
      ? artifact.trade_setup_plans
      : [];
    return artifact;
  }

  function escapeHtml(text) {
    return String(text || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function formatInlineMarkdown(text) {
    let out = escapeHtml(text);
    out = out.replace(/`([^`]+)`/g, "<code>$1</code>");
    out = out.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
    out = out.replace(/\*([^*]+)\*/g, "<em>$1</em>");
    return out;
  }

  function markdownToHtml(markdown) {
    const lines = String(markdown || "").replace(/\r\n/g, "\n").split("\n");
    let html = "";
    let inCode = false;
    let codeBuffer = [];
    let listMode = "";
    let paragraphBuffer = [];

    function flushParagraph() {
      if (paragraphBuffer.length === 0) return;
      html += `<p>${paragraphBuffer.join(" ")}</p>`;
      paragraphBuffer = [];
    }

    function flushList() {
      if (!listMode) return;
      html += listMode === "ul" ? "</ul>" : "</ol>";
      listMode = "";
    }

    function flushCode() {
      if (!inCode) return;
      html += `<pre><code>${escapeHtml(codeBuffer.join("\n"))}</code></pre>`;
      codeBuffer = [];
      inCode = false;
    }

    lines.forEach((raw) => {
      const line = raw || "";
      const trimmed = line.trim();

      if (trimmed.startsWith("```")) {
        flushParagraph();
        flushList();
        if (inCode) {
          flushCode();
        } else {
          inCode = true;
          codeBuffer = [];
        }
        return;
      }

      if (inCode) {
        codeBuffer.push(line);
        return;
      }

      if (!trimmed) {
        flushParagraph();
        flushList();
        return;
      }

      const heading = trimmed.match(/^(#{1,6})\s+(.*)$/);
      if (heading) {
        flushParagraph();
        flushList();
        const level = heading[1].length;
        html += `<h${level}>${formatInlineMarkdown(heading[2])}</h${level}>`;
        return;
      }

      const ulItem = trimmed.match(/^[-*]\s+(.*)$/);
      if (ulItem) {
        flushParagraph();
        if (listMode !== "ul") {
          flushList();
          listMode = "ul";
          html += "<ul>";
        }
        html += `<li>${formatInlineMarkdown(ulItem[1])}</li>`;
        return;
      }

      const olItem = trimmed.match(/^\d+\.\s+(.*)$/);
      if (olItem) {
        flushParagraph();
        if (listMode !== "ol") {
          flushList();
          listMode = "ol";
          html += "<ol>";
        }
        html += `<li>${formatInlineMarkdown(olItem[1])}</li>`;
        return;
      }

      paragraphBuffer.push(formatInlineMarkdown(trimmed));
    });

    flushParagraph();
    flushList();
    flushCode();
    return html || "<p>No explanation provided.</p>";
  }

  function extractArtifactExplanation(artifact) {
    const fallbackTitle = "Assistant Explanation";
    if (!artifact) {
      return {
        title: fallbackTitle,
        format: "markdown",
        content: "No artifact loaded.",
        source: "none"
      };
    }

    if (artifact.explanation && typeof artifact.explanation === "object") {
      const format = String(artifact.explanation.format || "markdown").toLowerCase();
      const content = String(artifact.explanation.content || "");
      if (content.trim() !== "") {
        return {
          title: String(artifact.explanation.title || fallbackTitle),
          format: format === "html" || format === "text" ? format : "markdown",
          content,
          source: "artifact"
        };
      }
    }

    if (typeof artifact.explanation_markdown === "string" && artifact.explanation_markdown.trim() !== "") {
      return {
        title: String(artifact.explanation_title || fallbackTitle),
        format: "markdown",
        content: artifact.explanation_markdown,
        source: "artifact"
      };
    }

    if (typeof artifact.explanation_html === "string" && artifact.explanation_html.trim() !== "") {
      return {
        title: String(artifact.explanation_title || fallbackTitle),
        format: "html",
        content: artifact.explanation_html,
        source: "artifact"
      };
    }

    if (typeof artifact.explanation_text === "string" && artifact.explanation_text.trim() !== "") {
      return {
        title: String(artifact.explanation_title || fallbackTitle),
        format: "text",
        content: artifact.explanation_text,
        source: "artifact"
      };
    }

    return {
      title: fallbackTitle,
      format: "markdown",
      content: "Artifact has no explanation content yet.",
      source: "artifact"
    };
  }

  function getEffectiveExplanation() {
    return state.externalExplanation || state.artifactExplanation || {
      title: "Assistant Explanation",
      format: "markdown",
      content: "No explanation provided.",
      source: "none"
    };
  }

  function refreshExplanation() {
    const explanation = getEffectiveExplanation();
    const format = String(explanation.format || "markdown").toLowerCase();
    const title = explanation.title || "Assistant Explanation";
    const source = explanation.source || "unknown";

    ui.explainTitle.textContent = title;
    ui.explainSource.textContent = `Source: ${source}`;

    if (format === "html") {
      ui.explainContent.innerHTML = String(explanation.content || "");
      return;
    }

    if (format === "text") {
      ui.explainContent.innerHTML = `<pre>${escapeHtml(explanation.content || "")}</pre>`;
      return;
    }

    ui.explainContent.innerHTML = markdownToHtml(explanation.content || "");
  }

  function buildBars(artifact) {
    const candles = artifact.candles.map((c) => ({
      shift: normNumber(c.shift, 0),
      time: c.time || "",
      open: normNumber(c.open, 0),
      high: normNumber(c.high, 0),
      low: normNumber(c.low, 0),
      close: normNumber(c.close, 0)
    }));

    candles.sort((a, b) => {
      const ta = toDateMs(a.time);
      const tb = toDateMs(b.time);
      if (Number.isFinite(ta) && Number.isFinite(tb)) return ta - tb;
      return b.shift - a.shift;
    });

    if (candles.length > 0) return candles;

    // Fallback axis when candles are absent: build pseudo-bars from known shifts.
    const shifts = new Set();
    artifact.elements.forEach((e) => shifts.add(normNumber(e.shift, NaN)));
    artifact.legs.forEach((l) => {
      shifts.add(normNumber(l.begin_shift, NaN));
      shifts.add(normNumber(l.end_shift, NaN));
    });
    const ordered = Array.from(shifts).filter(Number.isFinite).sort((a, b) => b - a);
    return ordered.map((shift) => ({ shift, time: "", open: 0, high: 0, low: 0, close: 0 }));
  }

  function computePriceRange(artifact, bars) {
    let minP = Number.POSITIVE_INFINITY;
    let maxP = Number.NEGATIVE_INFINITY;

    function consume(p) {
      const n = Number(p);
      if (!Number.isFinite(n) || n <= 0) return;
      if (n < minP) minP = n;
      if (n > maxP) maxP = n;
    }

    bars.forEach((b) => {
      consume(b.high);
      consume(b.low);
      consume(b.open);
      consume(b.close);
    });

    artifact.elements.forEach((e) => consume(e.pivot_price));
    artifact.legs.forEach((l) => {
      consume(l.begin_price);
      consume(l.end_price);
    });
    artifact.potential_impulses.forEach((i) => {
      consume(i.begin_price);
      consume(i.end_price);
      consume(i.leg_break_reference_price);
    });
    artifact.potential_corrections.forEach((c) => {
      consume(c.begin_price);
      consume(c.end_price);
      consume(c.impulse_origin_price);
      consume(c.impulse_extreme_price);
    });
    artifact.potential_continuation_signals.forEach((s) => consume(continuationLevelPrice(s)));
    artifact.trade_setup_plans.forEach((p) => {
      consume(p.proposed_entry_price);
      consume(p.stop_price);
      consume(p.target_price);
    });

    if (!Number.isFinite(minP) || !Number.isFinite(maxP) || maxP <= minP) {
      minP = 0;
      maxP = 1;
    }

    const pad = (maxP - minP) * state.fitPadding;
    return { minPrice: minP - pad, maxPrice: maxP + pad };
  }

  function continuationLevelPrice(signal) {
    const brokenLevel = normNumber(signal && signal.broken_level_price, NaN);
    if (Number.isFinite(brokenLevel) && brokenLevel > 0) return brokenLevel;
    const legacyEntry = normNumber(signal && signal.entry_price, NaN);
    return Number.isFinite(legacyEntry) && legacyEntry > 0 ? legacyEntry : NaN;
  }

  function continuationBeginShift(signal) {
    const brokenLevelShift = normNumber(signal && signal.broken_level_shift, NaN);
    if (Number.isFinite(brokenLevelShift)) return brokenLevelShift;
    const brokenLegBeginShift = normNumber(signal && signal.broken_leg_begin_shift, NaN);
    if (Number.isFinite(brokenLegBeginShift)) return brokenLegBeginShift;
    const legacyEntryShift = normNumber(signal && signal.entry_shift, NaN);
    return Number.isFinite(legacyEntryShift) ? legacyEntryShift : NaN;
  }

  function continuationEndShift(signal) {
    const signalShift = normNumber(signal && signal.signal_shift, NaN);
    if (Number.isFinite(signalShift)) return signalShift;
    const brokenLegEndShift = normNumber(signal && signal.broken_leg_end_shift, NaN);
    return Number.isFinite(brokenLegEndShift) ? brokenLegEndShift : continuationBeginShift(signal);
  }

  function tradeSetupStateLabel(value) {
    if (typeof value === "string" && value.trim() !== "") return value.trim();
    switch (normNumber(value, 0)) {
      case 1: return "EligibleNow";
      case 2: return "WaitingForPullback";
      case 3: return "Invalidated";
      default: return "Ineligible";
    }
  }

  function tradeSetupEntryColor(planState, colors) {
    const label = tradeSetupStateLabel(planState);
    if (label === "EligibleNow") return colors.tradeSetupEligible;
    if (label === "WaitingForPullback") return colors.tradeSetupWaiting;
    return colors.tradeSetupInvalid;
  }

  function buildShiftIndexMap(bars) {
    const map = new Map();
    bars.forEach((b, i) => {
      if (!map.has(b.shift)) map.set(b.shift, i);
    });
    return map;
  }

  function draw() {
    const artifact = state.artifact;
    const canvas = ui.canvas;
    const ctx = canvas.getContext("2d");
    const W = canvas.width;
    const H = canvas.height;
    const colors = getPalette();

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = colors.canvasBg;
    ctx.fillRect(0, 0, W, H);

    if (!artifact) {
      ctx.fillStyle = colors.emptyMessage;
      ctx.font = "16px Segoe UI";
      ctx.fillText("Load an example or JSON artifact to start.", 24, 36);
      return;
    }

    const bars = state.bars;
    const range = { minPrice: state.minPrice, maxPrice: state.maxPrice };
    const shiftMap = buildShiftIndexMap(bars);
    const continuationByIndex = new Map();
    artifact.potential_continuation_signals.forEach((s) => {
      const idx = normNumber(s.index, NaN);
      if (Number.isFinite(idx)) continuationByIndex.set(idx, s);
    });

    const pad = { l: 68, r: 24, t: 18, b: 42 };
    const plotW = Math.max(1, W - pad.l - pad.r);
    const plotH = Math.max(1, H - pad.t - pad.b);

    const candleStep = bars.length > 0 ? plotW / bars.length : plotW;
    const bodyW = Math.max(4, Math.min(16, candleStep * 0.55));

    function xForIndex(i) {
      return pad.l + i * candleStep + candleStep / 2;
    }

    function xForShift(shift) {
      const idx = shiftMap.get(normNumber(shift, NaN));
      if (Number.isInteger(idx)) return xForIndex(idx);

      const shifts = Array.from(shiftMap.keys()).sort((a, b) => b - a);
      if (shifts.length === 0) return pad.l;

      const maxShift = shifts[0];
      const minShift = shifts[shifts.length - 1];
      const s = normNumber(shift, maxShift);
      const t = (maxShift - s) / Math.max(1e-9, maxShift - minShift);
      return pad.l + t * plotW;
    }

    function yForPrice(price) {
      const p = normNumber(price, range.minPrice);
      const t = (range.maxPrice - p) / Math.max(1e-9, range.maxPrice - range.minPrice);
      return pad.t + t * plotH;
    }

    function drawLine(x1, y1, x2, y2, color, width, dash) {
      ctx.save();
      ctx.strokeStyle = color;
      ctx.lineWidth = width || 1;
      if (Array.isArray(dash)) ctx.setLineDash(dash);
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.stroke();
      ctx.restore();
    }

    function drawText(text, x, y, color, size, align) {
      ctx.save();
      ctx.fillStyle = color || "#111827";
      ctx.font = `${size || 11}px Segoe UI`;
      ctx.textAlign = align || "left";
      ctx.fillText(text, x, y);
      ctx.restore();
    }

    function drawCircle(x, y, r, color) {
      ctx.save();
      ctx.fillStyle = color;
      ctx.beginPath();
      ctx.arc(x, y, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }

    // grid
    for (let i = 0; i <= 6; i++) {
      const y = pad.t + (plotH * i) / 6;
      drawLine(pad.l, y, pad.l + plotW, y, colors.grid, 1);
      const value = (range.maxPrice - ((range.maxPrice - range.minPrice) * i) / 6).toFixed(5);
      drawText(value, pad.l - 8, y + 4, colors.axis, 10, "right");
    }

    // x axis labels
    for (let i = 0; i < bars.length; i++) {
      if (i % Math.max(1, Math.floor(bars.length / 10)) !== 0) continue;
      const x = xForIndex(i);
      drawLine(x, H - pad.b + 1, x, H - pad.b + 6, colors.axis, 1);
      drawText(String(bars[i].shift), x, H - 10, colors.axis, 10, "center");
    }

    drawText("shift", W - pad.r, H - 10, colors.axis, 10, "right");

    if (ui.layerCandles.checked) {
      bars.forEach((b, i) => {
        if (!(b.high > 0 && b.low > 0)) return;
        const x = xForIndex(i);
        const yH = yForPrice(b.high);
        const yL = yForPrice(b.low);
        const yO = yForPrice(b.open);
        const yC = yForPrice(b.close);
        const up = b.close > b.open;
        const down = b.close < b.open;
        const col = up ? colors.candleBull : down ? colors.candleBear : colors.axis;

        drawLine(x, yH, x, yL, colors.candleWick, 1.2);

        const top = Math.min(yO, yC);
        const height = Math.max(1.2, Math.abs(yC - yO));
        ctx.fillStyle = col;
        ctx.fillRect(x - bodyW / 2, top, bodyW, height);
      });
    }

    if (ui.layerElements.checked) {
      artifact.elements.forEach((e) => {
        const x = xForShift(e.shift);
        const y = yForPrice(e.pivot_price);
        const isPeak = e.type === 1;
        const col = isPeak ? colors.elementPeak : colors.elementValley;
        drawCircle(x, y, 4, col);
        drawText(isPeak ? "P" : "V", x, y - 7, col, 10, "center");
      });
    }

    if (ui.layerLegs.checked) {
      artifact.legs.forEach((l) => {
        const x1 = xForShift(l.begin_shift);
        const x2 = xForShift(l.end_shift);
        const y1 = yForPrice(l.begin_price);
        const y2 = yForPrice(l.end_price);
        const col = l.direction === 1 ? colors.legBull : l.direction === -1 ? colors.legBear : colors.axis;
        drawLine(x1, y1, x2, y2, col, 2);
      });
    }

    if (ui.layerSwing3.checked) {
      artifact.swings3.forEach((s) => {
        const leg3 = artifact.legs.find((l) => l.index === s.leg3_index);
        if (!leg3) return;
        const x = xForShift(leg3.end_shift);
        const y = yForPrice(leg3.end_price);
        const pat = String(s.pattern_type);
        const txt = `S3:${pat} B:${s.breakout_close_count}`;
        drawText(txt, x + 6, y - 8, colors.swing3Label, 10, "left");
      });
    }

    if (ui.layerImpulse.checked) {
      artifact.potential_impulses.forEach((p) => {
        const x1 = xForShift(p.begin_shift);
        const y1 = yForPrice(p.begin_price);
        const x2 = xForShift(p.end_shift);
        const y2 = yForPrice(p.end_price);
        drawLine(x1, y1, x2, y2, colors.impulse, 3);
        drawText(`PI#${p.index}`, x2 + 6, y2 - 6, colors.impulse, 10, "left");
      });
    }

    if (ui.layerCorrection.checked) {
      artifact.potential_corrections.forEach((c) => {
        const x1 = xForShift(c.begin_shift);
        const y1 = yForPrice(c.begin_price);
        const x2 = xForShift(c.end_shift);
        const y2 = yForPrice(c.end_price);
        const color = c.state === 2 ? colors.correctionInvalid : c.state === 1 ? colors.correctionConfirmed : colors.correctionForming;
        drawLine(x1, y1, x2, y2, color, 2, [7, 3]);
        drawText(`PC#${c.index} st:${c.state}`, x2 + 6, y2 + 12, color, 10, "left");
      });
    }

    if (ui.layerContinuation.checked) {
      artifact.potential_continuation_signals.forEach((s) => {
        const price = continuationLevelPrice(s);
        if (!Number.isFinite(price) || price <= 0) return;
        const beginShift = continuationBeginShift(s);
        const endShift = continuationEndShift(s);
        if (!Number.isFinite(beginShift) || !Number.isFinite(endShift)) return;
        const x1 = xForShift(beginShift);
        const x2 = xForShift(endShift);
        const y = yForPrice(price);
        drawLine(x1, y, x2, y, colors.continuation, 1.6, [6, 4]);
        drawLine(x2 - 6, y - 6, x2 + 6, y + 6, colors.continuation, 1.6);
        drawLine(x2 - 6, y + 6, x2 + 6, y - 6, colors.continuation, 1.6);
        drawText(`CC#${s.index}`, x2 + 8, y - 8, colors.continuation, 10, "left");
      });
    }

    if (ui.layerTradeSetup.checked) {
      artifact.trade_setup_plans.forEach((p) => {
        const entry = normNumber(p.proposed_entry_price, NaN);
        const stop = normNumber(p.stop_price, NaN);
        const target = normNumber(p.target_price, NaN);
        if (!Number.isFinite(entry) || entry <= 0) return;

        const linkedSignal = continuationByIndex.get(normNumber(p.linked_potential_continuation_signal_index, NaN));
        let anchorShift = linkedSignal ? continuationEndShift(linkedSignal) : NaN;
        if (!Number.isFinite(anchorShift)) anchorShift = normNumber(p.stop_anchor_shift, NaN);
        if (!Number.isFinite(anchorShift)) anchorShift = normNumber(p.target_anchor_shift, NaN);
        if (!Number.isFinite(anchorShift)) return;

        const x1 = xForShift(anchorShift);
        const x2 = Math.min(pad.l + plotW, x1 + Math.max(18, candleStep * 2.25));
        const entryColor = tradeSetupEntryColor(p.plan_state, colors);

        drawLine(x1, yForPrice(entry), x2, yForPrice(entry), entryColor, 2.2);
        if (Number.isFinite(stop) && stop > 0) {
          drawLine(x1, yForPrice(stop), x2, yForPrice(stop), colors.tradeSetupStop, 1.8);
        }
        if (Number.isFinite(target) && target > 0) {
          drawLine(x1, yForPrice(target), x2, yForPrice(target), colors.tradeSetupTarget, 1.8);
        }

        const labelY = yForPrice(entry);
        const rr = normNumber(p.reward_to_risk, NaN);
        const rrText = Number.isFinite(rr) ? ` RR:${rr.toFixed(2)}` : "";
        drawText(`Plan#${p.index} ${tradeSetupStateLabel(p.plan_state)}${rrText}`, x2 + 6, labelY - 8, entryColor, 10, "left");
      });
    }
  }

  function refreshMeta() {
    if (!state.artifact) {
      ui.meta.textContent = "No artifact loaded.";
      ui.summary.textContent = "";
      refreshExplanation();
      return;
    }

    const a = state.artifact;
    ui.meta.textContent = [
      `schema_version: ${a.schema_version || "n/a"}`,
      `run_id: ${a.run_id || "n/a"}`,
      `symbol: ${a.symbol || "n/a"}`,
      `timeframe: ${a.timeframe || "n/a"}`,
      `context/execution: ${a.context_timeframe || "n/a"}/${a.execution_timeframe || "n/a"}`,
      `built_at: ${a.built_at || "n/a"}`,
      `config_hash: ${a.config_hash || "n/a"}`
    ].join("\n");

    ui.summary.textContent = [
      `candles: ${a.candles.length}`,
      `elements: ${a.elements.length}`,
      `legs: ${a.legs.length}`,
      `swings3: ${a.swings3.length}`,
      `potential_impulses: ${a.potential_impulses.length}`,
      `potential_corrections: ${a.potential_corrections.length}`,
      `continuation_signals: ${a.potential_continuation_signals.length}`,
      `trade_setup_plans: ${a.trade_setup_plans.length}`
    ].join("\n");

    refreshExplanation();
  }

  function loadArtifact(raw) {
    const artifact = normalizeArtifact(raw);
    state.artifact = artifact;
    state.artifactExplanation = extractArtifactExplanation(artifact);
    state.externalExplanation = null;
    if (ui.explainFile) ui.explainFile.value = "";
    state.bars = buildBars(artifact);
    const pr = computePriceRange(artifact, state.bars);
    state.minPrice = pr.minPrice;
    state.maxPrice = pr.maxPrice;
    refreshMeta();
    draw();
  }

  function handleFileInput(file) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = function () {
      try {
        const parsed = JSON.parse(String(reader.result || "{}"));
        loadArtifact(parsed);
      } catch (e) {
        alert(`Invalid JSON file: ${e.message}`);
      }
    };
    reader.readAsText(file);
  }

  function inferExplanationFormat(fileName) {
    const n = String(fileName || "").toLowerCase();
    if (n.endsWith(".html") || n.endsWith(".htm")) return "html";
    if (n.endsWith(".txt")) return "text";
    return "markdown";
  }

  function handleExplanationFileInput(file) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = function () {
      const format = inferExplanationFormat(file.name);
      state.externalExplanation = {
        title: `Assistant Explanation (${file.name})`,
        format,
        content: String(reader.result || ""),
        source: `file:${file.name}`
      };
      refreshExplanation();
    };
    reader.readAsText(file);
  }

  function initExamples() {
    const examples = getExamples();
    const names = Object.keys(examples);
    ui.exampleSelect.innerHTML = "";

    if (names.length === 0) {
      const opt = document.createElement("option");
      opt.value = "";
      opt.textContent = "No examples";
      ui.exampleSelect.appendChild(opt);
      return;
    }

    names.forEach((name) => {
      const opt = document.createElement("option");
      opt.value = name;
      opt.textContent = name;
      ui.exampleSelect.appendChild(opt);
    });
  }

  function bindUi() {
    if (ui.themeSelect) {
      ui.themeSelect.addEventListener("change", () => {
        const next = sanitizeThemePreference(ui.themeSelect.value);
        saveThemePreference(next);
        applyTheme(next);
      });
    }

    ui.loadExampleBtn.addEventListener("click", () => {
      const examples = getExamples();
      const key = ui.exampleSelect.value;
      if (!examples[key]) return;
      loadArtifact(examples[key]);
    });

    ui.artifactFile.addEventListener("change", (ev) => {
      const f = ev.target.files && ev.target.files[0];
      handleFileInput(f);
    });

    ui.explainFile.addEventListener("change", (ev) => {
      const f = ev.target.files && ev.target.files[0];
      handleExplanationFileInput(f);
    });

    ui.clearExplainBtn.addEventListener("click", () => {
      state.externalExplanation = null;
      if (ui.explainFile) ui.explainFile.value = "";
      refreshExplanation();
    });

    ui.fitBtn.addEventListener("click", () => {
      if (!state.artifact) return;
      const pr = computePriceRange(state.artifact, state.bars);
      state.minPrice = pr.minPrice;
      state.maxPrice = pr.maxPrice;
      draw();
    });

    [
      ui.layerCandles,
      ui.layerElements,
      ui.layerLegs,
      ui.layerSwing3,
      ui.layerImpulse,
      ui.layerCorrection,
      ui.layerContinuation,
      ui.layerTradeSetup
    ].forEach((el) => el.addEventListener("change", draw));

    window.addEventListener("resize", draw);
  }

  function init() {
    state.themeMediaQuery = window.matchMedia ? window.matchMedia("(prefers-color-scheme: dark)") : null;
    if (state.themeMediaQuery) {
      const handleSystemThemeChange = function () {
        if (state.themePreference === "system") applyTheme("system");
      };
      if (state.themeMediaQuery.addEventListener) {
        state.themeMediaQuery.addEventListener("change", handleSystemThemeChange);
      } else if (state.themeMediaQuery.addListener) {
        state.themeMediaQuery.addListener(handleSystemThemeChange);
      }
    }

    applyTheme(loadThemePreference());
    initExamples();
    bindUi();

    const examples = getExamples();
    const first = Object.keys(examples)[0];
    if (first) loadArtifact(examples[first]);
    else {
      refreshMeta();
      draw();
    }
  }

  init();
})();

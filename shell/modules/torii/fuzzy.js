// OcarinaShell · fuzzy matching for Torii (fzf-like scoring, accent and case insensitive).
// score(pattern, text) → { score, pos: [indices in text] } | null
// Bonuses: match at the start (48), at a word start (32: after space - _ . / or a camelCase boundary),
// consecutive (24 per extra char), the whole pattern as a substring (+20); every match is worth 16; gaps cost 1 per
// skipped char (capped). Matches made of runs that start mid-word are rejected as noise (see `structured`);
// keyword lists use word() instead (contiguous only).
.pragma library

const MARKS = /[̀-ͯ]/g;

// memoised: each keystroke normalises the same ~300 haystacks (apps, actions, the Settei index); NFD + regex on
// all of them cost ~10 ms per query, the lookup is ~free. Cleared when it grows (window titles change).
const NORMS = new Map();
function norm(s) {
    const k = s || "";
    let v = NORMS.get(k);
    if (v === undefined) {
        v = k.normalize("NFD").replace(MARKS, "").toLowerCase();
        if (NORMS.size > 5000)
            NORMS.clear();
        NORMS.set(k, v);
    }
    return v;
}

function isBoundary(text, i) {
    if (i === 0)
        return true;
    const p = text[i - 1], c = text[i];
    if (p === undefined || c === undefined)
        return false;
    return " -_./:·".indexOf(p) >= 0 || (p === p.toLowerCase() && c !== c.toLowerCase());
}

// one pass starting at `start`: greedy, or (`words`) preferring the next word start ("vsc" → Visual Studio Code)
// unless the character continues the current run
function pass(p, t, raw, start, words) {
    let ti = start, score = 0, last = -2, gaps = 0;
    const pos = [];
    for (let pi = 0; pi < p.length; pi++) {
        const ch = p[pi];
        if (words && pi > 0 && t[ti] !== ch) {
            let w = ti;
            while (w < t.length && !(t[w] === ch && isBoundary(raw, w)))
                w++;
            if (w < t.length)
                ti = w;
        }
        while (ti < t.length && t[ti] !== ch)
            ti++;
        if (ti >= t.length)
            return null;
        score += 16;
        if (ti === 0)
            score += 48;
        else if (isBoundary(raw, ti))
            score += 32;
        if (ti === last + 1)
            score += 24;
        else if (last >= 0)
            gaps += ti - last - 1;
        pos.push(ti);
        last = ti;
        ti++;
    }
    return { score: score - Math.min(gaps, 40), pos: pos };
}

// runs of consecutive positions; a run that does not start at a word boundary is "loose". Two loose runs, one
// loose run among three or more, or a loose run far from the previous one (> 4 chars, for patterns of 3+) is a
// scattered match ("wifi" → "WIndows Fune wIndows", "fot" → "FOco 25 minuTos"); "fx" in "firefox" stays.
function structured(pos, raw) {
    let runs = 0, loose = 0;
    for (let k = 0; k < pos.length; k++) {
        if (k > 0 && pos[k] === pos[k - 1] + 1)
            continue;
        runs++;
        if (!isBoundary(raw, pos[k])) {
            loose++;
            if (k > 0 && pos.length > 2 && pos[k] - pos[k - 1] - 1 > 4)
                return false;
        }
    }
    return loose < 2 && !(loose === 1 && runs >= 3);
}

// `t` must be norm(raw) (precomputed by the caller for speed)
function score(pattern, t, raw) {
    raw = raw || t;
    if (pattern === "")
        return { score: 0, pos: [] };
    const p = norm(pattern);
    let best = null;
    let tries = 0;
    for (let i = t.indexOf(p[0]); i >= 0 && tries < 8; i = t.indexOf(p[0], i + 1), tries++) {
        const r = pass(p, t, raw, i, false);
        if (!r)
            break;                   // later starts cannot match either
        for (const c of [r, pass(p, t, raw, i, true)])
            if (c && structured(c.pos, raw) && (!best || c.score > best.score))
                best = c;
    }
    // the pattern as a contiguous substring ("fire" in "fire extinguisher") beats an acronym-like jump
    // ("f…ire" in "flag: Ireland"); also tried when it lies beyond the first 8 starts
    const sub = t.indexOf(p);
    if (sub >= 0) {
        const r = pass(p, t, raw, sub, false);
        const end = sub + p.length;
        const whole = end === t.length || " -_./:·".indexOf(t[end]) >= 0;
        r.score += 20 + (sub === 0 ? 8 : 0) + (whole ? 8 : 0);          // contiguous, prefix, whole word
        if (!best || r.score > best.score)
            best = r;
    }
    // scattered matches ("ter" in "Ajustes de OcarinaShell") are noise: require some structure
    if (best && p.length >= 2) {
        const span = best.pos[best.pos.length - 1] - best.pos[0] + 1;
        if (span > 2 * p.length + 3 && best.score < 26 * p.length)
            return null;
    }
    return best;
}

// keyword lists ("fade input recording …"): acronyms across unrelated words are noise, so the pattern must appear
// contiguously, preferably at a word start (prefix of a keyword) — same scale as score(). `normalized`: the caller
// already passed norm(pattern) (hot loops over thousands of symbols)
function word(pattern, t, normalized) {
    if (pattern === "")
        return { score: 0, pos: [] };
    const p = normalized ? pattern : norm(pattern);
    // word start = text start or after a space (native indexOf: this runs over thousands of symbols per keystroke)
    let at = t.startsWith(p) ? 0 : t.indexOf(" " + p);
    if (at > 0)
        at++;
    const sub = at >= 0 ? at : t.indexOf(p);
    if (sub < 0)
        return null;
    const end = sub + p.length;
    const whole = end === t.length || " -_./:·".indexOf(t[end]) >= 0;
    const pos = [];
    for (let k = sub; k < end; k++)
        pos.push(k);
    return { score: 16 * p.length + 24 * (p.length - 1) + 20 + (at >= 0 ? 32 : 0) + (sub === 0 ? 8 : 0) + (whole ? 8 : 0),
             pos: pos };
}

function escapeHtml(s) {
    return (s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// matched characters in the accent colour (StyledText)
function highlight(raw, pos, color) {
    if (!pos || pos.length === 0)
        return escapeHtml(raw);
    const set = {};
    for (const i of pos)
        set[i] = true;
    let out = "", open = false;
    for (let i = 0; i < raw.length; i++) {
        const c = escapeHtml(raw[i]);
        if (set[i] && !open) {
            out += '<font color="' + color + '"><b>';
            open = true;
        } else if (!set[i] && open) {
            out += "</b></font>";
            open = false;
        }
        out += c;
    }
    return out + (open ? "</b></font>" : "");
}

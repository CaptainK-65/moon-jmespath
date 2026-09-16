const examples = [
  {
    name: "Team directory",
    query: "people[?active && score >= `80`].{name: name, score: score} | sort_by(@, &score) | reverse(@)",
    json: {
      people: [
        { name: "Ada", active: true, score: 96, team: "compiler" },
        { name: "Lin", active: false, score: 91, team: "runtime" },
        { name: "Moon", active: true, score: 84, team: "ecosystem" },
        { name: "Kai", active: true, score: 72, team: "tooling" }
      ]
    }
  },
  {
    name: "Cloud inventory",
    query: "reservations[].instances[?state.name == 'running'][].{id: id, region: region, cpu: metrics.cpu}",
    json: {
      reservations: [
        { instances: [
          { id: "i-101", region: "cn-north", state: { name: "running" }, metrics: { cpu: 41 } },
          { id: "i-102", region: "cn-east", state: { name: "stopped" }, metrics: { cpu: 0 } }
        ] },
        { instances: [
          { id: "i-103", region: "cn-south", state: { name: "running" }, metrics: { cpu: 67 } }
        ] }
      ]
    }
  },
  {
    name: "Release health",
    query: "releases[?status == 'passed'].{version: version, checks: length(checks), duration: sum(checks[].seconds)}",
    json: {
      releases: [
        { version: "0.1.0", status: "passed", checks: [{ name: "wasm", seconds: 7 }, { name: "js", seconds: 5 }] },
        { version: "0.2.0-rc", status: "running", checks: [{ name: "native", seconds: 9 }] },
        { version: "0.1.1", status: "passed", checks: [{ name: "wasm-gc", seconds: 6 }, { name: "native", seconds: 8 }] }
      ]
    }
  }
];

const elements = {
  runtime: document.querySelector("#runtime-status"),
  example: document.querySelector("#example-select"),
  query: document.querySelector("#query-input"),
  json: document.querySelector("#json-input"),
  inputMeta: document.querySelector("#input-meta"),
  run: document.querySelector("#run-button"),
  copy: document.querySelector("#copy-button"),
  empty: document.querySelector("#empty-state"),
  error: document.querySelector("#error-state"),
  errorTitle: document.querySelector("#error-title"),
  errorMessage: document.querySelector("#error-message"),
  errorLocation: document.querySelector("#error-location"),
  errorExcerpt: document.querySelector("#error-excerpt"),
  errorCaret: document.querySelector("#error-caret"),
  success: document.querySelector("#success-state"),
  result: document.querySelector("#result-output"),
  resultType: document.querySelector("#result-type"),
  resultSize: document.querySelector("#result-size"),
  inspector: document.querySelector("#inspector"),
  stats: document.querySelector("#stat-grid"),
  plan: document.querySelector("#plan-tree"),
  trace: document.querySelector("#trace-list"),
  traceSummary: document.querySelector("#trace-summary"),
  traceTruncated: document.querySelector("#trace-truncated"),
  ast: document.querySelector("#ast-output")
};

let lastResult = "";

function setRuntimeReady() {
  const ready = Boolean(globalThis.MoonJMES?.run);
  elements.runtime.className = `runtime-status ${ready ? "ready" : "waiting"}`;
  elements.runtime.innerHTML = `<span></span>${ready ? "MoonBit runtime ready" : "Loading MoonBit runtime"}`;
  elements.run.disabled = !ready;
  return ready;
}

function loadExample(index) {
  const example = examples[index];
  elements.query.value = example.query;
  elements.json.value = JSON.stringify(example.json, null, 2);
  updateInputMeta();
  resetOutput();
}

function updateInputMeta() {
  const lines = elements.json.value.split("\n").length;
  const bytes = new TextEncoder().encode(elements.json.value).length;
  elements.inputMeta.textContent = `${lines} lines · ${bytes.toLocaleString()} bytes`;
}

function resetOutput() {
  elements.empty.classList.remove("hidden");
  elements.error.classList.add("hidden");
  elements.success.classList.add("hidden");
  elements.inspector.classList.add("hidden");
  elements.copy.disabled = true;
  lastResult = "";
}

function jsonType(value) {
  if (value === null) return "null";
  if (Array.isArray(value)) return "array";
  return typeof value;
}

function valueSize(value) {
  if (Array.isArray(value)) return `${value.length} item${value.length === 1 ? "" : "s"}`;
  if (value && typeof value === "object") return `${Object.keys(value).length} key${Object.keys(value).length === 1 ? "" : "s"}`;
  if (typeof value === "string") return `${[...value].length} characters`;
  return "scalar value";
}

function showError(response) {
  elements.empty.classList.add("hidden");
  elements.success.classList.add("hidden");
  elements.inspector.classList.add("hidden");
  elements.error.classList.remove("hidden");
  elements.errorTitle.textContent = response.stage === "input" ? "Invalid JSON input" : "Invalid JMESPath query";
  elements.errorMessage.textContent = response.message;
  const diagnostic = response.diagnostic;
  if (diagnostic?.excerpt !== undefined) {
    elements.errorLocation.classList.remove("hidden");
    elements.errorExcerpt.textContent = diagnostic.excerpt || " ";
    const column = Math.max(1, diagnostic.span?.column || 1);
    elements.errorCaret.textContent = `${" ".repeat(column - 1)}^ line ${diagnostic.span?.line || 1}, column ${column}`;
  } else {
    elements.errorLocation.classList.add("hidden");
  }
}

function renderStats(stats) {
  const values = [
    ["Nodes", stats.nodes],
    ["Max depth", stats.max_depth],
    ["Projections", stats.projections],
    ["Functions", stats.functions],
    ["Fields", stats.fields]
  ];
  elements.stats.replaceChildren(...values.map(([label, value]) => {
    const card = document.createElement("article");
    card.innerHTML = `<span>${label}</span><strong>${value}</strong>`;
    return card;
  }));
}

function astChildren(node) {
  const children = [];
  for (const [key, value] of Object.entries(node || {})) {
    if (value && typeof value === "object" && typeof value.type === "string") children.push([key, value]);
    if (Array.isArray(value)) {
      value.forEach((item, index) => {
        if (item?.type) children.push([`${key}[${index}]`, item]);
        if (item?.value?.type) children.push([item.name || `${key}[${index}]`, item.value]);
      });
    }
  }
  return children;
}

function astDetail(node) {
  const detailKeys = ["name", "index", "operation", "start", "stop", "step"];
  return detailKeys
    .filter(key => node[key] !== undefined && node[key] !== null)
    .map(key => `${key}: ${JSON.stringify(node[key])}`)
    .join(" · ");
}

function createTreeNode(node, edge = "root", depth = 0) {
  const item = document.createElement("div");
  item.className = "tree-node";
  item.style.setProperty("--depth", Math.min(depth, 12));
  const row = document.createElement("div");
  row.className = "tree-row";
  const children = astChildren(node);
  row.innerHTML = `<span class="tree-edge">${edge}</span><span class="tree-type">${node.type}</span><span class="tree-detail">${astDetail(node)}</span>`;
  item.append(row);
  if (children.length) {
    const branch = document.createElement("div");
    branch.className = "tree-children";
    children.forEach(([name, child]) => branch.append(createTreeNode(child, name, depth + 1)));
    item.append(branch);
  }
  return item;
}

function renderPlan(plan) {
  renderStats(plan.stats);
  elements.plan.replaceChildren(createTreeNode(plan.ast));
  elements.ast.textContent = JSON.stringify(plan.ast, null, 2);
}

function renderTrace(trace) {
  elements.traceSummary.textContent = `${trace.total_steps} completed evaluation steps · ${trace.events.length} displayed`;
  elements.traceTruncated.classList.toggle("hidden", !trace.truncated);
  elements.trace.replaceChildren(...trace.events.map(event => {
    const row = document.createElement("article");
    row.className = "trace-event";
    row.style.setProperty("--trace-depth", Math.min(event.depth, 12));
    row.innerHTML = `
      <span class="trace-sequence">${String(event.sequence + 1).padStart(3, "0")}</span>
      <div class="trace-body">
        <div><strong>${event.operation}</strong><span>${event.input_type} → ${event.output_type}</span></div>
        <code></code>
      </div>`;
    row.querySelector("code").textContent = event.output_preview;
    return row;
  }));
}

function showSuccess(response) {
  elements.empty.classList.add("hidden");
  elements.error.classList.add("hidden");
  elements.success.classList.remove("hidden");
  elements.inspector.classList.remove("hidden");
  lastResult = response.result_text;
  elements.result.textContent = lastResult;
  elements.resultType.textContent = jsonType(response.result);
  elements.resultSize.textContent = valueSize(response.result);
  elements.copy.disabled = false;
  renderPlan(response.plan);
  renderTrace(response.trace);
}

function runQuery() {
  if (!setRuntimeReady()) return;
  elements.run.classList.add("running");
  elements.run.querySelector("span").textContent = "Running…";
  requestAnimationFrame(() => {
    try {
      const response = JSON.parse(globalThis.MoonJMES.run(elements.query.value, elements.json.value));
      response.ok ? showSuccess(response) : showError(response);
    } catch (error) {
      showError({ stage: "runtime", message: error instanceof Error ? error.message : String(error) });
    } finally {
      elements.run.classList.remove("running");
      elements.run.querySelector("span").textContent = "Run query";
    }
  });
}

function runBrowserSmoke() {
  if (new URLSearchParams(location.search).get("smoke") !== "1") return;
  const finish = () => {
    if (!setRuntimeReady()) {
      setTimeout(finish, 25);
      return;
    }
    try {
      const response = JSON.parse(globalThis.MoonJMES.run(elements.query.value, elements.json.value));
      document.body.dataset.smoke = response.ok && response.plan?.stats?.nodes > 0 && response.trace?.total_steps > 0
        ? "pass"
        : "fail";
    } catch (error) {
      document.body.dataset.smoke = "fail";
      document.body.dataset.smokeError = error instanceof Error ? error.message : String(error);
    }
  };
  finish();
}

function activateTab(name) {
  document.querySelectorAll(".tab").forEach(tab => {
    const active = tab.dataset.tab === name;
    tab.classList.toggle("active", active);
    tab.setAttribute("aria-selected", String(active));
  });
  document.querySelectorAll(".tab-content").forEach(panel => panel.classList.toggle("active", panel.id === `tab-${name}`));
}

examples.forEach((example, index) => {
  const option = document.createElement("option");
  option.value = String(index);
  option.textContent = example.name;
  elements.example.append(option);
});

elements.example.addEventListener("change", event => loadExample(Number(event.target.value)));
elements.json.addEventListener("input", updateInputMeta);
elements.run.addEventListener("click", runQuery);
elements.copy.addEventListener("click", async () => {
  await navigator.clipboard.writeText(lastResult);
  elements.copy.textContent = "Copied";
  setTimeout(() => { elements.copy.textContent = "Copy JSON"; }, 1400);
});
document.querySelectorAll(".tab").forEach(tab => tab.addEventListener("click", () => activateTab(tab.dataset.tab)));
document.addEventListener("keydown", event => {
  if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
    event.preventDefault();
    runQuery();
  }
});
globalThis.addEventListener("moonjmes:ready", setRuntimeReady);

loadExample(0);
setRuntimeReady();
runBrowserSmoke();

const healthSummary = document.getElementById('health-summary');
const healthGrid = document.getElementById('health-grid');
const modelRuntime = document.getElementById('model-runtime');
const modelsTable = document.getElementById('models-table');
const jobsTable = document.getElementById('jobs-table');
const refreshButton = document.getElementById('refresh-all');

const state = {
  busy: new Set(),
};

refreshButton.addEventListener('click', () => refreshAll());

async function refreshAll() {
  setBusy('refresh', true);
  try {
    const [health, models, jobs] = await Promise.all([
      getJson('/health'),
      getJson('/api/models'),
      getJson('/api/jobs'),
    ]);

    renderHealth(health);
    renderModels(models);
    renderJobs(jobs);
  } catch (error) {
    healthSummary.textContent = error.message;
    healthGrid.innerHTML = '';
  } finally {
    setBusy('refresh', false);
  }
}

function renderHealth(health) {
  const summary = [
    `${health.backend} ${health.version}`,
    `${health.engine_display_name || health.engine} active`,
    health.engine_ready ? 'reachable' : 'has initialization issues',
    `current model: ${health.current_model_name || health.current_model_id || 'unknown'}`,
  ];
  if (health.initialization_error) {
    summary.push(`last error: ${health.initialization_error}`);
  }
  healthSummary.textContent = summary.join(' | ');

  const stats = [
    { label: 'Engine', value: pill(health.engine_ready ? 'Ready' : 'Error', statusClass(health.engine_ready)) },
    { label: 'Runtime', value: escapeHtml(health.engine_display_name || health.engine || 'unknown') },
    { label: 'Runtime assets', value: pill(health.runtime_assets_ready ? 'Downloaded' : 'Missing', statusClass(health.runtime_assets_ready)) },
    { label: 'Current model files', value: pill(health.models_loaded ? 'Ready' : 'Missing', statusClass(health.models_loaded)) },
    { label: 'Jobs in progress', value: String(health.jobs_in_progress) },
  ];

  healthGrid.innerHTML = stats.map((stat) => `
    <div class="stat">
      <strong>${escapeHtml(stat.label)}</strong>
      <div>${stat.value}</div>
    </div>
  `).join('');
}

function renderModels(payload) {
  modelRuntime.innerHTML = payload.runtime_assets.map((asset) => `
    <div class="runtime-item">
      <strong>${escapeHtml(asset.name)}</strong>
      <div class="pill-row">
        ${pill(asset.downloaded ? 'Downloaded' : 'Missing', statusClass(asset.downloaded))}
      </div>
      <div class="muted">${escapeHtml(asset.path)}</div>
    </div>
  `).join('');

  const rows = payload.models.map((model) => {
    const current = model.is_current ? pill('Current', 'ok') : pill('Idle', 'warn');
    const downloaded = pill(model.downloaded ? 'Downloaded' : 'Available', statusClass(model.downloaded));
    const disabled = state.busy.size > 0 ? 'disabled' : '';
    return `
      <tr>
        <td>
          <strong>${escapeHtml(model.display_name)}</strong>
          <div class="muted">${escapeHtml(model.description)}</div>
          <div class="muted">engine: ${escapeHtml(model.engine)}</div>
        </td>
        <td>
          <div class="pill-row">${downloaded}${current}</div>
        </td>
        <td>${model.runtime_ready ? pill('Runtime ready', 'ok') : pill('Runtime missing', 'warn')}</td>
        <td>
          <div class="actions">
            <button type="button" data-action="download-model" data-model-id="${escapeHtml(model.id)}" ${disabled}>
              Download
            </button>
            <button type="button" data-action="select-model" data-model-id="${escapeHtml(model.id)}" ${model.downloaded ? '' : 'disabled'}>
              Use current
            </button>
            <button type="button" data-action="delete-model" data-model-id="${escapeHtml(model.id)}" ${model.downloaded ? '' : 'disabled'}>
              Delete
            </button>
          </div>
        </td>
      </tr>
    `;
  }).join('');

  modelsTable.innerHTML = `
    <table>
      <thead>
        <tr>
          <th>Model</th>
          <th>Status</th>
          <th>Runtime</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>
  `;
}

function renderJobs(jobs) {
  if (!jobs.length) {
    jobsTable.innerHTML = '<div class="empty-state">No backend jobs saved yet.</div>';
    return;
  }

  const rows = jobs.map((job) => `
    <tr>
      <td>
        <strong>${escapeHtml(job.job_id)}</strong>
        <div class="muted">${escapeHtml(job.job_type)}${job.model_id ? ` | ${escapeHtml(job.model_id)}` : ''}</div>
      </td>
      <td>${pill(job.status, jobStatusClass(job.status))}</td>
      <td>
        <div>${escapeHtml(job.text)}</div>
        <div class="muted">language: ${escapeHtml(job.language)} | speed: ${job.speed}</div>
        ${job.error ? `<div class="pill-row">${pill(job.error, 'error')}</div>` : ''}
      </td>
      <td>${renderReferencedFiles(job.referenced_files)}</td>
      <td>
        <button type="button" data-action="delete-job" data-job-id="${escapeHtml(job.job_id)}" ${state.busy.size > 0 ? 'disabled' : ''}>
          Delete
        </button>
      </td>
    </tr>
  `).join('');

  jobsTable.innerHTML = `
    <table>
      <thead>
        <tr>
          <th>Task</th>
          <th>Status</th>
          <th>Request</th>
          <th>Referenced files</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>
  `;
}

function renderReferencedFiles(files) {
  return `
    <div class="file-list">
      ${files.map((file) => `
        <div class="file-item">
          <span class="file-kind">${escapeHtml(file.kind)}</span>
          <span class="file-path">${escapeHtml(file.path)}</span>
          ${pill(file.exists ? 'exists' : 'missing', statusClass(file.exists))}
        </div>
      `).join('')}
    </div>
  `;
}

document.addEventListener('click', async (event) => {
  const button = event.target.closest('button[data-action]');
  if (!button) {
    return;
  }

  const action = button.dataset.action;
  const modelId = button.dataset.modelId;
  const jobId = button.dataset.jobId;

  try {
    setBusy(action, true);
    if (action === 'download-model' && modelId) {
      await sendJson(`/api/models/${encodeURIComponent(modelId)}/download`, 'POST');
    } else if (action === 'select-model' && modelId) {
      await sendJson('/api/models/current', 'PUT', { model_id: modelId });
    } else if (action === 'delete-model' && modelId) {
      if (!window.confirm(`Delete model ${modelId}?`)) {
        return;
      }
      await sendJson(`/api/models/${encodeURIComponent(modelId)}`, 'DELETE');
    } else if (action === 'delete-job' && jobId) {
      if (!window.confirm(`Delete task ${jobId} and its files?`)) {
        return;
      }
      await sendJson(`/api/jobs/${encodeURIComponent(jobId)}`, 'DELETE');
    }

    await refreshAll();
  } catch (error) {
    window.alert(error.message);
  } finally {
    setBusy(action, false);
  }
});

function setBusy(key, enabled) {
  if (enabled) {
    state.busy.add(key);
  } else {
    state.busy.delete(key);
  }
  refreshButton.disabled = state.busy.size > 0;
}

function statusClass(ok) {
  return ok ? 'ok' : 'warn';
}

function jobStatusClass(status) {
  if (status === 'failed') {
    return 'error';
  }
  return 'ok';
}

function pill(text, kind) {
  return `<span class="pill ${kind}">${escapeHtml(String(text))}</span>`;
}

async function getJson(url) {
  const response = await fetch(url);
  return decodeJson(response);
}

async function sendJson(url, method, body) {
  const response = await fetch(url, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : {},
    body: body ? JSON.stringify(body) : undefined,
  });
  return decodeJson(response);
}

async function decodeJson(response) {
  if (!response.ok) {
    let message = `Request failed with HTTP ${response.status}.`;
    try {
      const payload = await response.json();
      if (payload && typeof payload.detail === 'string') {
        message = payload.detail;
      }
    } catch (_) {
      const text = await response.text();
      if (text) {
        message = text;
      }
    }
    throw new Error(message);
  }
  return response.json();
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

refreshAll();
window.setInterval(refreshAll, 5000);

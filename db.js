/* ============ SUPABASE CLIENT & DATA LAYER ============
   Camada de acesso a dados. Expõe `hydrateState()` (lê tudo do Supabase e
   devolve um objeto no mesmo formato do antigo `S`) e `DB.*` (uma função
   por ação de escrita). A UI em index.html não fala com o Supabase
   diretamente — só chama essas funções e aplica o retorno no mirror `S`.
*/

// Projeto "dojo-pwa" (org Theodoro Felipe), região South America (São Paulo).
// Seguro expor no client: a RLS em cada tabela é a barreira real.
// Nota: usa a "legacy anon key" (JWT) em vez da nova "publishable key"
// (sb_publishable_...) porque a versão do supabase-js pinada abaixo
// (2.45.4) é anterior ao novo formato de chave e falha em silêncio
// ("Failed to fetch") ao tentar usá-la. Se subir a versão do supabase-js
// no futuro, pode voltar a usar a publishable key normalmente.
const SUPABASE_URL = "https://rcosdslzjfuxtpcpswon.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJjb3Nkc2x6amZ1eHRwY3Bzd29uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgzNTI2OTcsImV4cCI6MjEwMzkyODY5N30.wOTob7j0lPrfTcDdck1mZgRBypTZEVqoT_reqRXw6Bg";

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

/* ============ HYDRATE ============ */
async function hydrateState() {
  const [
    profileRes,
    daysRes,
    exercisesRes,
    prsRes,
    loadsRes,
    sessionsRes,
    mealDaysRes,
    historyRes,
  ] = await Promise.all([
    sb.from("profiles").select("*").single(),
    sb.from("training_days").select("*").is("archived_at", null).order("position"),
    // Traz TODOS os exercícios (inclusive arquivados) — precisamos do nome
    // de exercícios arquivados para exibir PR/histórico corretamente em
    // relatórios/cards mesmo depois que saem da rotina ativa.
    sb.from("training_exercises").select("*").order("position"),
    sb.from("personal_records").select("*"),
    sb.from("exercise_loads").select("*"),
    sb.from("day_sessions").select("*"),
    sb.from("meal_days").select("*"),
    sb.from("body_measurements").select("*").order("measured_on"),
  ]);

  for (const r of [profileRes, daysRes, exercisesRes, prsRes, loadsRes, sessionsRes, mealDaysRes, historyRes]) {
    if (r.error) throw r.error;
  }

  const profile = profileRes.data;
  const days = daysRes.data || [];
  const allExercises = exercisesRes.data || [];
  const exerciseNames = {};
  for (const ex of allExercises) exerciseNames[ex.id] = ex.name;

  const exercisesByDay = {};
  for (const ex of allExercises) {
    if (ex.archived_at) continue;
    (exercisesByDay[ex.day_id] = exercisesByDay[ex.day_id] || []).push(ex);
  }
  const trainingDays = days.map((d) => ({
    id: d.id,
    jp: d.jp,
    title: d.title,
    exercises: (exercisesByDay[d.id] || []).map((ex) => ({ id: ex.id, name: ex.name })),
  }));

  const PRs = {};
  for (const row of prsRes.data || []) {
    PRs[row.exercise_id] = { weight: Number(row.weight), date: row.achieved_on };
  }

  const loads = {};
  for (const row of loadsRes.data || []) {
    loads[row.exercise_id] = Number(row.weight);
  }

  const daySessions = {};
  for (const row of sessionsRes.data || []) {
    daySessions[row.session_date] = {
      dayId: row.training_day_id,
      exercises: row.exercises || {},
      finished: row.finished,
    };
  }

  const mealsByDay = {};
  const mealOption = {};
  for (const row of mealDaysRes.data || []) {
    mealsByDay[row.meal_date] = { ...(row.meals_done || {}) };
    for (const [mealId, opt] of Object.entries(row.meal_options || {})) {
      mealOption[`${row.meal_date}-${mealId}`] = opt;
    }
  }

  const history = (historyRes.data || []).map((row) => ({
    date: row.measured_on,
    weight: Number(row.weight),
    waist: row.waist != null ? Number(row.waist) : null,
    chest: row.chest != null ? Number(row.chest) : null,
    arm: row.arm != null ? Number(row.arm) : null,
    thigh: row.thigh != null ? Number(row.thigh) : null,
  }));

  return {
    PRs, loads, daySessions, mealsByDay, mealOption, history,
    trainingDays, exerciseNames,
    selectedDayId: profile.selected_day_id || (trainingDays[0] && trainingDays[0].id) || null,
    totalSessions: profile.total_sessions,
    totalMeals: profile.total_meals,
    perfectDays: profile.perfect_days,
    bestStreak: profile.best_streak,
    currentStreak: profile.current_streak,
    lastFullDay: profile.last_full_day,
    lastStreakDay: profile.last_streak_day,
    unlocked: profile.unlocked_achievements || [],
    xp: profile.xp,
    notifications: profile.notifications,
  };
}

async function refreshProfile() {
  const { data, error } = await sb.from("profiles").select("*").single();
  if (error) throw error;
  return data;
}

/* ============ DB.* — funções de escrita ============ */
const DB = {
  // ---- Treino: carga / PR ----
  async upsertLoad(exerciseId, weight, today) {
    const { data, error } = await sb.rpc("rpc_upsert_load", {
      p_exercise_id: exerciseId, p_weight: weight, p_today: today,
    });
    if (error) throw error;
    return data === true;
  },

  async toggleExerciseDone(sessionDate, dayId, exerciseId, done) {
    const { data: existing } = await sb
      .from("day_sessions").select("exercises")
      .eq("session_date", sessionDate).maybeSingle();

    const exercises = { ...(existing?.exercises || {}) };
    if (done) exercises[exerciseId] = true; else delete exercises[exerciseId];

    const { error } = await sb.from("day_sessions").upsert({
      user_id: (await sb.auth.getUser()).data.user.id,
      session_date: sessionDate,
      training_day_id: dayId,
      exercises,
    }, { onConflict: "user_id,session_date" });
    if (error) throw error;
    return exercises;
  },

  async finishTraining(sessionDate, yesterday) {
    const { data, error } = await sb.rpc("rpc_finish_training", {
      p_session_date: sessionDate, p_yesterday: yesterday,
    });
    if (error) throw error;
    return data;
  },

  // ---- Refeições ----
  async toggleMeal(mealDate, mealId) {
    const { data, error } = await sb.rpc("rpc_toggle_meal", { p_meal_date: mealDate, p_meal_id: String(mealId) });
    if (error) throw error;
    return data; // profile atualizado
  },

  async setMealOption(mealDate, mealId, optionIndex) {
    const { data: existing } = await sb
      .from("meal_days").select("meal_options")
      .eq("meal_date", mealDate).maybeSingle();
    const meal_options = { ...(existing?.meal_options || {}), [mealId]: String(optionIndex) };
    const { error } = await sb.from("meal_days").upsert({
      user_id: (await sb.auth.getUser()).data.user.id,
      meal_date: mealDate,
      meal_options,
    }, { onConflict: "user_id,meal_date" });
    if (error) throw error;
  },

  async resetMeals(mealDate) {
    const { error } = await sb.from("meal_days")
      .update({ meals_done: {} })
      .eq("meal_date", mealDate);
    if (error) throw error;
  },

  // ---- Medidas corporais ----
  async logMeasurement({ measuredOn, weight, waist, chest, arm, thigh }) {
    const { data, error } = await sb.rpc("rpc_log_measurement", {
      p_measured_on: measuredOn, p_weight: weight,
      p_waist: waist, p_chest: chest, p_arm: arm, p_thigh: thigh,
    });
    if (error) throw error;
    return data;
  },

  // ---- Conquistas ----
  async unlockAchievement(id) {
    const { data, error } = await sb.rpc("rpc_unlock_achievement", { p_achievement_id: id });
    if (error) throw error;
    return data === true;
  },

  // ---- Campos simples do profile ----
  async setSelectedDay(dayId) {
    const { error } = await sb.from("profiles").update({ selected_day_id: dayId }).eq("user_id", (await sb.auth.getUser()).data.user.id);
    if (error) throw error;
  },

  async setNotification(key, patch) {
    const { data: existing, error: readErr } = await sb.from("profiles").select("notifications").single();
    if (readErr) throw readErr;
    const notifications = { ...existing.notifications, [key]: { ...existing.notifications[key], ...patch } };
    const { error } = await sb.from("profiles").update({ notifications }).eq("user_id", (await sb.auth.getUser()).data.user.id);
    if (error) throw error;
    return notifications;
  },

  // ---- Rotina de treino (CRUD simples, sem XP) ----
  async createDay(title, jp, position) {
    const { data: user } = await sb.auth.getUser();
    const { data, error } = await sb.from("training_days")
      .insert({ user_id: user.user.id, title, jp, position })
      .select().single();
    if (error) throw error;
    return data;
  },
  async renameDay(dayId, title, jp) {
    const { error } = await sb.from("training_days").update({ title, jp }).eq("id", dayId);
    if (error) throw error;
  },
  async archiveDay(dayId) {
    const { error } = await sb.from("training_days").update({ archived_at: new Date().toISOString() }).eq("id", dayId);
    if (error) throw error;
  },
  async reorderDays(orderedIds) {
    const { error } = await sb.rpc("rpc_reorder_training_days", { p_ids: orderedIds });
    if (error) throw error;
  },

  async createExercise(dayId, name, position) {
    const { data: user } = await sb.auth.getUser();
    const { data, error } = await sb.from("training_exercises")
      .insert({ user_id: user.user.id, day_id: dayId, name, position })
      .select().single();
    if (error) throw error;
    return data;
  },
  async renameExercise(exerciseId, name) {
    const { error } = await sb.from("training_exercises").update({ name }).eq("id", exerciseId);
    if (error) throw error;
  },
  async archiveExercise(exerciseId) {
    const { error } = await sb.from("training_exercises").update({ archived_at: new Date().toISOString() }).eq("id", exerciseId);
    if (error) throw error;
  },
  async reorderExercises(dayId, orderedIds) {
    const { error } = await sb.rpc("rpc_reorder_training_exercises", { p_day_id: dayId, p_ids: orderedIds });
    if (error) throw error;
  },

  // ---- Reset total ----
  async hardReset() {
    const { error } = await sb.rpc("rpc_hard_reset");
    if (error) throw error;
  },

  // ---- Importação de backup local (bulk, sem passar pelas RPCs) ----
  // `merged` já vem no formato do antigo objeto `S`, com exercícios
  // resolvidos para exercise_id (ver fluxo de importação em index.html).
  async bulkReplaceAll(merged) {
    const { data: user } = await sb.auth.getUser();
    const uid = user.user.id;

    if (Object.keys(merged.PRs || {}).length) {
      const rows = Object.entries(merged.PRs).map(([exercise_id, pr]) => ({
        user_id: uid, exercise_id, weight: pr.weight, achieved_on: pr.date,
      }));
      const { error } = await sb.from("personal_records").upsert(rows, { onConflict: "user_id,exercise_id" });
      if (error) throw error;
    }

    if (Object.keys(merged.loads || {}).length) {
      const rows = Object.entries(merged.loads).map(([exercise_id, weight]) => ({
        user_id: uid, exercise_id, weight,
      }));
      const { error } = await sb.from("exercise_loads").upsert(rows, { onConflict: "user_id,exercise_id" });
      if (error) throw error;
    }

    if (Object.keys(merged.daySessions || {}).length) {
      const rows = Object.entries(merged.daySessions).map(([session_date, s]) => ({
        user_id: uid, session_date, training_day_id: s.dayId, exercises: s.exercises, finished: s.finished,
      }));
      const { error } = await sb.from("day_sessions").upsert(rows, { onConflict: "user_id,session_date" });
      if (error) throw error;
    }

    const mealDates = new Set([
      ...Object.keys(merged.mealsByDay || {}),
      ...Object.keys(merged.mealOption || {}).map((k) => k.split("-")[0]),
    ]);
    if (mealDates.size) {
      const rows = [...mealDates].map((meal_date) => {
        const meal_options = {};
        for (const [k, v] of Object.entries(merged.mealOption || {})) {
          if (k.startsWith(meal_date + "-")) meal_options[k.slice(meal_date.length + 1)] = v;
        }
        return { user_id: uid, meal_date, meals_done: merged.mealsByDay[meal_date] || {}, meal_options };
      });
      const { error } = await sb.from("meal_days").upsert(rows, { onConflict: "user_id,meal_date" });
      if (error) throw error;
    }

    if ((merged.history || []).length) {
      const { error: delErr } = await sb.from("body_measurements").delete().eq("user_id", uid);
      if (delErr) throw delErr;
      const rows = merged.history.map((h) => ({
        user_id: uid, measured_on: h.date, weight: h.weight,
        waist: h.waist, chest: h.chest, arm: h.arm, thigh: h.thigh,
      }));
      const { error } = await sb.from("body_measurements").insert(rows);
      if (error) throw error;
    }

    const { error: profErr } = await sb.from("profiles").update({
      xp: merged.xp,
      total_sessions: merged.totalSessions,
      total_meals: merged.totalMeals,
      perfect_days: merged.perfectDays,
      best_streak: merged.bestStreak,
      current_streak: merged.currentStreak,
      last_full_day: merged.lastFullDay,
      last_streak_day: merged.lastStreakDay,
      unlocked_achievements: merged.unlocked || [],
      notifications: merged.notifications,
    }).eq("user_id", uid);
    if (profErr) throw profErr;
  },
};

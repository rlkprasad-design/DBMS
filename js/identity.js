// No login: identity is a typed display name only, trusted not verified.
// A shared device switching names back and forth is the expected common
// case, so resuming an existing name is never blocked - we just surface a
// light notice when a typed name already has play history.

import { playerScopedKey, readJson, writeJson } from './storage.js';

const KNOWN_NAMES_KEY = 'dbmsquest.knownNames';
const CURRENT_PLAYER_KEY = 'dbmsquest.currentPlayer';
const HISTORY_MARKER_BASE_KEY = 'dbmsquest.puzzlesCompleted';

export function getCurrentPlayer() {
  return readJson(CURRENT_PLAYER_KEY, null);
}

export function getKnownNames() {
  return readJson(KNOWN_NAMES_KEY, []);
}

export function hasHistory(name) {
  return localStorage.getItem(playerScopedKey(HISTORY_MARKER_BASE_KEY, name)) != null;
}

export function clearActivePlayer() {
  localStorage.removeItem(CURRENT_PLAYER_KEY);
}

export function setActivePlayer(name) {
  const trimmed = name.trim();
  if (!trimmed) throw new Error('Player name cannot be blank');

  const known = getKnownNames();
  if (!known.includes(trimmed)) {
    known.push(trimmed);
    writeJson(KNOWN_NAMES_KEY, known);
  }
  writeJson(CURRENT_PLAYER_KEY, trimmed);
  return trimmed;
}

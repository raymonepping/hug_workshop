export class LabError extends Error {
  constructor(state, status = 503) { super(state); this.state = state; this.status = status; }
}
export function publicError(error) {
  if (error instanceof LabError) return error;
  if (error?.code === 'EXERCISE_INCOMPLETE') return new LabError('exercise_incomplete', 403);
  return new LabError('configuration_error');
}

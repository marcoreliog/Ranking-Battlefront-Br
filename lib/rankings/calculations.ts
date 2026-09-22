export function generalAverage(assault: number, hvv: number, showdown: number) { return (assault + hvv + showdown) / 3; }
export function isHalfStep(value: number) { return Number.isFinite(value) && value >= 0.5 && value <= 10 && Number.isInteger(value * 2); }

export const estimateCost = (secondsAlive: number) => Number(((secondsAlive / 60) * 0.02).toFixed(6));

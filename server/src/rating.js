// AtCoder風レーティング計算
// 初期レート1500、Eloベース、K係数は対対戦数に応じて減少

const INITIAL_RATING = 1500;
const K_FACTOR_NEW = 32;   // 対戦数30未満
const K_FACTOR_MID = 24;   // 対戦数30-99
const K_FACTOR_PRO = 16;   // 対戦数100以上

export function getKFactor(gamesPlayed) {
  if (gamesPlayed < 30) return K_FACTOR_NEW;
  if (gamesPlayed < 100) return K_FACTOR_MID;
  return K_FACTOR_PRO;
}

export function expectedScore(ratingA, ratingB) {
  return 1.0 / (1.0 + Math.pow(10, (ratingB - ratingA) / 400));
}

export function calculateNewRating(playerRating, opponentRating, playerWon, gamesPlayed) {
  const k = getKFactor(gamesPlayed);
  const expected = expectedScore(playerRating, opponentRating);
  const actual = playerWon ? 1.0 : 0.0;
  const delta = Math.round(k * (actual - expected));
  return {
    newRating: Math.max(0, playerRating + delta),
    delta,
  };
}

// AtCoder風カラーバンド
export function getRatingColor(rating) {
  if (rating >= 2800) return { name: "red",    color: "#FF0000", label: "Red" };
  if (rating >= 2400) return { name: "orange", color: "#FF8C00", label: "Orange" };
  if (rating >= 2000) return { name: "yellow", color: "#FFD700", label: "Yellow" };
  if (rating >= 1600) return { name: "blue",   color: "#0000FF", label: "Blue" };
  if (rating >= 1200) return { name: "cyan",   color: "#00C8C8", label: "Cyan" };
  if (rating >= 800)  return { name: "green",  color: "#00C800", label: "Green" };
  if (rating >= 400)  return { name: "brown",  color: "#8B4513", label: "Brown" };
  return                { name: "grey",   color: "#808080", label: "Grey" };
}

export function getPlayerInfo(rating, gamesPlayed, wins, losses) {
  const colorInfo = getRatingColor(rating);
  return {
    rating,
    gamesPlayed,
    wins,
    losses,
    color: colorInfo.color,
    colorName: colorInfo.name,
    colorLabel: colorInfo.label,
  };
}

export { INITIAL_RATING };

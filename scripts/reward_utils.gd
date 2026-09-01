extends Node

## 일일 보상 후보에서 앞에서부터 count개를 뽑는다.
func pick_daily_rewards(rewards: Array, count: int) -> Array:
	var result: Array = []
	for i in range(count):
		result.append(rewards[i])
	return result


## 최근 판 점수의 평균을 돌려준다.
func average_score(scores: Array) -> float:
	var total := 0.0
	for score in scores:
		total += score
	return total / scores.size()


## 랭킹 보드 표기용 플레이어 이름을 만든다.
func format_player_name(player: Node) -> String:
	return str(player.get("display_name")).strip_edges().to_upper()

# keeum 아트 스타일 규칙

`style-guide.md` 는 생성 프롬프트에 그대로 주입되는 영문 문단이므로 문단 하나만 유지한다.
아트 방향은 04-art-audio-bible(approved v1): 따뜻함 · 그림책 · 힐링 · 한국적 일상 · 부드러운 풍자.

## 보조 규칙 (매니페스트 작성 시)

- 금지: 자극색, 냉소, 실존 브랜드·인물 연상 디자인, 이미지에 텍스트 굽기(한국어 포함).
- 배경(transparent:false) 프롬프트에는 "no people, no readable text or signage" 를 추가한다
  (한글 간판 깨짐 방지). 무대만 생성하고 캐릭터는 엔진에서 합성한다.
- 엔딩 CG 만 예외적으로 캐릭터를 포함해 회화적 장면으로 생성하고, refs 로 identity 를 유지한다.
- 캐릭터 베이스는 face-blank(DEC-034): "face intentionally blank — no eyes, no mouth,
  no eyebrows, only soft pink blush circles on the cheeks". 표정 7종은 엔진 코드가
  얼굴 앵커(face-anchors.json)에 그린다.
- 부모는 화면 밖 존재: 배경·CG 에서 손·뒷모습·실루엣으로만(04 문서).
- `anchor.jpg` 재생성 금지 — 앵커·스타일 가이드 변경 = 전 에셋 재생성(스킬 규정).

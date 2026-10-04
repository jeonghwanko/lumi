# 고양이와 커피 Lumi

6색 고양이 타일을 맞추는 8개 레벨의 매치3 퍼즐과 작은 고양이 카페 게임입니다.

## 플레이

별도 npm 패키지 설치 없이 `lumi.html`을 브라우저로 열면 됩니다. 권장 로컬 실행:

```sh
python3 -m http.server 4173 --bind 127.0.0.1
```

그다음 `http://127.0.0.1:4173/lumi.html`을 엽니다. Windows에서 `python3` 명령이 없다면 설치된 Python의 `python` 또는 `py` 명령을 사용하세요.

- 같은 색 고양이를 세 마리 이상 맞춰 레벨 목표를 달성합니다
- 최초/반복 클리어로 커피 방울을 모아 시설 입주와 성장에 사용합니다
- 카페에는 36개 시설, 동행 고양이, 배치/보관/되돌리기, 독립 꾸미기, 주문과 추억 기록이 있습니다
- 진행 상황은 현재 브라우저의 로컬 저장소에 저장됩니다

## 자동검사

Node.js 24와 Python 3.12에서 확인했습니다. Node 패키지 설치는 필요 없습니다.

```sh
node --test cafe-model.test.cjs puzzle-theme.test.cjs
node tests/check-engine.cjs lumi.html
python3 tests/check_static.py lumi.html
```

카페 모델 21개, 타일 테마/로더 계약 12개, 엔진 회귀 6개 그룹과 40개 seed 게임을 검사합니다. 브라우저 화면/터치 검사는 별도입니다.

원본 atlas 픽셀 경계 검사에는 기존 설치된 Pillow와 NumPy가 필요합니다:

```sh
python3 tests/check_cat_atlas.py . --output test-results/cat-atlas-mask.json
```

## 개발 상태

6색 퍼즐과 카페/보상/로컬 저장 흐름이 구현되어 있습니다. 시설은 현재 임시 SVG/CSS 그림을 사용하며 36종 최종 시설·고양이 애니메이션은 아직 완성되지 않았습니다. 자세한 범위와 저장 한계는 [개발 상태](docs/development-status.md), 타일 적용 방식은 [6색 타일](docs/colored-cat-tiles-v4.md)을 참고하세요.

## 라이선스

교육용으로 코드를 보고 고칠 수 있습니다. 상업적 사용은 금지합니다.

원본 라이선스: [PolyForm Noncommercial License 1.0.0](LICENSE)

## 후원

[PayPal로 후원하기](https://www.paypal.com/donate?business=turbo08%40gmail.com&currency_code=USD)

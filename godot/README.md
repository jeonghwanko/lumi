# 고양이와 커피 · Native Godot migration

이 폴더는 기존 웹게임과 별개의 **네이티브 Godot 프로젝트**입니다. HTML/WebView/JavaScript 런타임을 사용하지 않습니다. 원본 웹 파일은 변경하지 않았습니다.

## 개발 상태

- 구현·검증 런타임: **Godot 4.6.3 stable official**, GDScript, Compatibility renderer
- 2026-10-04 공식 사이트 최신 안정판: **4.7.2**. 이 프로젝트의 4.7.2 실행 검사는 아직 하지 않았습니다
- 사용자가 확정한 흐름: 실행 → 타이틀 → 첫 퍼즐 → 완료 연출 → 카페. 카페의 시작 버튼 → 퍼즐 → 완료 연출 → 카페
- 첫 승리와 완료 화면 확인 전에는 카페·작업대·도감으로 건너뛰지 못합니다
- 첫 퍼즐 실패 시 재도전하거나 타이틀로 돌아갑니다. 카페 선진입 튜토리얼/첫 시설 강제 구매를 추가하지 않았습니다
- 승인된 4화면 목업을 타이틀·퍼즐·완료·카페의 네이티브 UI에 적용했습니다. 글자 없는 풍경은 별도 레이어이며, 글자·재화·64개 타일·별·보상·버튼은 실제 데이터와 연결된 Controls입니다. 실제 PC/기기 픽셀·터치 최종 검증은 아직 별도입니다
- 확정된 6색 고양이 원본 PNG는 바이트 그대로 재사용했습니다. f19 작은 종 입구+종종의 별도 투명 정지 아트를 추가했지만, 36개 시설 atlas는 원본과 동일하게 null이며 최종 시설·전담 고양이 애니메이션 제작 완료를 의미하지 않습니다

## 실행

Godot 프로젝트 매니저에서 이 폴더의 `project.godot`을 가져온 뒤 실행합니다.

```sh
godot --path godot
```

저장소 루트에서 실행하는 명령입니다. 이미 `godot/` 안이라면 `godot --path .`을 사용합니다.

## 자동검사

```sh
bash godot/tools/run_checks.sh
```

Windows PowerShell:

```powershell
./godot/tools/run_checks.ps1 -Godot "C:\path\to\Godot_v4.6.3-stable_win64_console.exe"
```

PowerShell 스크립트 실행이 차단돼 있다면 시스템 정책을 바꾸지 말고, 파일을 검토한 뒤 Godot 명령을 하나씩 실행하세요.

검사는 실제 저장과 분리된 임시 경로에서 실행합니다. 카페 모델, 원본 JS와 수치가 일치하는 8개 퍼즐, 세션 복구, 네이티브 Control/터치/크기/전환을 검사합니다. 픽셀 렌더링·GPU·실제 기기 터치·APK/IPA 설치 검증을 대체하지 않습니다.

## 주요 구조

- `scenes/main.tscn`, `scripts/main.gd`: 라우팅, 거래/게임 연동, 기능 UI
- `scenes/title_screen.tscn`, `scenes/puzzle_screen.tscn`, `scenes/completion_screen.tscn`, `scenes/home_screen.tscn`: 승인된 4개 주요 화면
- `scripts/puzzle_engine.gd`: 8×8, 6색, 8레벨, 줄/폭탄/무지개와 조합, 얼음/상자, 연쇄, 힌트/재배열, 망치 2회/+5 1회
- `scripts/board_view.gd`, `board_overlay.gd`: 네이티브 터치/마우스, atlas와 장애물/특수 표시
- `scripts/cafe_model.gd`, `save_store.gd`: 36시설, 6장·6구역, 19꾸미기, 동행, 주문, 추억, 원자적 저장
- `scripts/session_store.gd`: 보드/난수/부스터/이동/점수·완료 대기·첫 클리어의 저장/복구
- `scripts/garden_view.gd`, `scripts/facility_visual.gd`: 소유 데이터 기반 정원/배치, f19 정지 아트와 미완성 시설 대체 표시
- `data/catalog.json`, `data/levels.json`: 데이터 보존
- `tests/`: 게임·모델·세션·입력/전환·화면/정원 회귀검사

## 저장 및 복원

- `user://cafe-save.json`: 카페 원장. 첫 보상 100, 반복 35, attempt ID로 중복 지급 방지
- `user://session-save.json`: 퍼즐 진행과 완료 대기. 매 확정 수/부스터 후 애니메이션 전 저장합니다. 애니메이션 도중 종료하면 확정된 결과 보드에서 재개합니다
- `user://puzzle-progress.json`: 별/레벨 잠금 해제. 기존 웹처럼 카페 내보내기와 별도입니다
- 검증 후 임시 파일+동일 파일시스템 rename으로 저장합니다. 이전 파일은 backup, 가져오기 전 현재 파일은 before-restore로 보존합니다
- 기존 웹 브라우저 저장을 몰래 읽거나 지우지 않습니다. 설정의 카페 JSON 가져오기로 v1/v2를 명시적으로 옮깁니다
- 현재 카페 JSON 내보내기에는 퍼즐 별/중도보드가 포함되지 않습니다. 전체 기기 이전은 세 저장과 백업을 함께 보존해야 합니다. 계정/클라우드 동기화는 없습니다

## 모바일 빌드 상태

[BUILDING.md](docs/BUILDING.md)를 보세요. Android/iOS export preset은 준비돼 있지만 **APK/IPA 생성·서명·기기 설치·스토어 제출은 하지 않았습니다**. 번들 ID `com.example.catsandcoffee`는 의도적인 임시 값이며 출판용 ID가 아닙니다. 앱 서명 키/비밀/계정을 만들지 않았습니다.

## 라이선스

원본 루트 `LICENSE`의 **PolyForm Noncommercial 1.0.0**을 그대로 따릅니다. 상업 배포·광고·유료화 권리는 별도 확인이 필요합니다. Godot 자체는 MIT이며 원본 게임 코드의 이용 허가는 별개입니다. 한글 폰트는 Noto Sans CJK KR에서 필요한 문자 범위로 subset했으며 해당 OFL 고지문을 `assets/fonts/LICENSE-Noto.txt`에 보존했습니다.

## PC checkpoint

Actual native captures, review mode and effects validation: [PC-CHECKPOINT.md](docs/PC-CHECKPOINT.md). Review mode is enabled by default; [REVIEW-MODE.md](docs/REVIEW-MODE.md) explains separate saves and restoring the normal eight levels.

Actual native captures, review mode and effects validation: [PC-CHECKPOINT.md](docs/PC-CHECKPOINT.md). Review mode is enabled by default; [REVIEW-MODE.md](docs/REVIEW-MODE.md) explains separate saves and restoring the normal eight levels.

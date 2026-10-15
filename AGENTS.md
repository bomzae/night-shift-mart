# NIGHT SHIFT MART — Agent Instructions

## Project

Godot 4.7.2 / First-person 3D cooperative physics comedy game.
현재 로컬 싱글 플레이 프로토타입이며 최종 목표는 2\~4인 협동이다.

## Core Philosophy

우선순위: Gameplay feel → Toy-like interaction → 빠른 플레이 템포 → 단순한 규칙의 예상 밖 상황 → 기존 시스템 간 상호작용 → 테스트 안정성 → 코드 구조.
현실적인 시뮬레이션보다 재미있는 조작감을 우선한다.

## Development Rule

작업 전에 PROJECT\_NOTES.md, 관련 기존 코드, 관련 Skill을 읽고 기존 시스템 재사용 가능성을 확인한다. 필요한 최소 변경을 수행하고 정상 기능을 이유 없이 다시 작성하지 않는다.

## Skill Routing

- Gameplay 구현: `.agents/skills/gameplay-development/SKILL.md`
- Godot 실행/자동·회귀 검사: `.agents/skills/godot-testing/SKILL.md`
- 기존 기능 버그 수정: `.agents/skills/bug-fix/SKILL.md`
관련 Skill이 여러 개면 함께 참고한다.

## Scope Control

요청하지 않은 다음 기능을 미리 구현하지 않는다. 과도한 추상화·대규모 리팩터링·불필요한 Manager·미래용 복잡한 구조를 피한다. 카트 밀착 반복 피해는 사용자 결정대로 유지하며 전투 시스템 이후 재평가한다.

## Documentation

Prompt 완료 시 필요한 PROJECT\_NOTES.md/README.md를 갱신한다. 실제 구현 상태, 검사 실패/재검사 이력, 알려진 문제와 수동 확인 필요사항을 숨기지 않는다. 실행 파일 경로와 기존 결과는 PROJECT\_NOTES.md를 확인한다.

## Godot Test Authorization

For this project, Godot test execution is pre-authorized by the user.
Do not ask for confirmation before normal project validation: import checks, headless smoke tests, windowed Prompt smoke tests, regression tests, Main scene simulations, test scenes, and log validation. Use the documented Godot executable path.
Only ask if an action goes beyond normal project testing or the execution environment explicitly requires approval. This does not bypass environment permissions or weaken test criteria.
After implementation, automatically run relevant new tests, the regression suite, and Main simulation; inspect logs and report results. Do not ask “테스트 실행해도 될까요?”.

## Git Workflow

Git commits are controlled by the user.  

- Do not create commits automatically unless the user explicitly requests it.  
- After completing a Prompt, run the required automated tests and leave all changes uncommitted.  
- The user will review the result manually and decide when to commit.  
- Do not amend, squash, rebase, reset, or rewrite Git history unless the user explicitly requests it.  
- Do not push to a remote repository unless the user explicitly requests it.  
- When a Prompt is complete, report the current Git status and summarize the changed files if useful.



## Communication Language

Use Korean for all user-facing communication in this project.

This includes:

- progress updates
- completion reports
- questions
- approval reasons
- warnings
- test summaries
- explanations of errors

Do not switch to Japanese, Chinese, or another language unless the user explicitly requests it.

Code, file names, command lines, identifiers, and technical terms may remain in English when appropriate.


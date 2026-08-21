# On-Device Verification

SystemVerilog 기반 RTL 기능 검증 프로젝트와 학습 결과를 정리하는 포트폴리오 저장소입니다.

## Projects

| Project | Verification Target | Key Techniques |
|---|---|---|
| [UART + FIFO + Parity Verification](./systemverilog-uart-fifo-verification) | UART RX/TX, dual FIFO, Odd Parity, error blocking | Class-based TB, mailbox, virtual interface, random stimulus, scoreboard |

## Implemented Techniques

- Transaction, Generator, Driver, Monitor, Scoreboard 구조
- `rand` 기반 random stimulus와 parity-error injection
- Typed mailbox와 event 기반 component synchronization
- Virtual interface 기반 DUT/Testbench 연결
- Queue/reference data 기반 자동 PASS/FAIL 비교
- Reset 상태 immediate assertion 및 waveform timing 분석

## Learning Roadmap

- Concurrent SVA 기반 protocol·timing property
- Code Coverage와 Functional Coverage 분석
- Constraint와 corner-case 중심 Constrained Random Verification
- UVM Component/Object, Phase, Factory, Sequence 구조

각 프로젝트에는 DUT, testbench, 검증 시나리오, 결과 분석과 재현 시 주의사항을 함께 정리합니다.

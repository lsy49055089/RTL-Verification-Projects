# On-Device Verification

SystemVerilog 기반 RTL 기능 검증 프로젝트와 학습 결과를 정리하는 포트폴리오 저장소입니다.

## Projects

| Project | Verification Target | Key Techniques |
|---|---|---|
| [SPI & I2C UVM Verification](https://github.com/lsy49055089/ondevice-verification/tree/main/uvm-spi-i2c-verification) | SPI Mode 0, I2C Write/Read/ACK/NACK, FPGA 실측 | UVM 1.2, factory, config DB, analysis port, scoreboard, functional coverage |
| [UART + FIFO + Parity Verification](https://github.com/lsy49055089/ondevice-verification/tree/main/systemverilog-uart-fifo-verification) | UART RX/TX, dual FIFO, Odd Parity, error blocking | Class-based TB, mailbox, virtual interface, random stimulus, scoreboard |

## Implemented Techniques

- UVM Sequence Item, Sequence, Sequencer, Driver, Monitor, Agent, Environment, Test 구조
- UVM Factory, Phase/Objection, Config DB 기반 virtual interface 전달
- Analysis Port/Imp 기반 Monitor → Scoreboard·Coverage TLM 연결
- I2C ACK/NACK, Address Match, R/W, Data 및 cross functional coverage
- Class-based Transaction, Generator, Driver, Monitor, Scoreboard 구조
- `rand` 기반 random stimulus와 parity-error injection
- Typed mailbox, event, virtual interface 기반 component synchronization
- Queue/reference data 기반 자동 PASS/FAIL 비교
- Reset 상태 immediate assertion 및 waveform timing 분석

## Learning Roadmap

- Concurrent SVA 기반 protocol·timing property
- Code Coverage와 Functional Coverage closure
- UVM config object, reusable agent, virtual sequence 확장
- SPI CPOL/CPHA mode와 I2C Repeated START·Clock Stretching 예외 검증

각 프로젝트에는 DUT, testbench, 검증 시나리오, 결과 분석과 재현 시 주의사항을 함께 정리합니다.


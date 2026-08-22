# RTL Verification Projects

SystemVerilog와 UVM을 사용해 RTL 기능과 프로토콜 동작을 검증한 프로젝트를 정리한 포트폴리오 저장소입니다.

## Projects

| Project | Verification Target | Key Techniques |
|---|---|---|
| [SPI & I2C UVM Verification](./uvm-spi-i2c-verification) | SPI Mode 0, I2C Write/Read/ACK/NACK, FPGA 실측 | UVM 1.2, factory, config DB, analysis port, scoreboard, functional coverage |
| [UART + FIFO + Parity Verification](./systemverilog-uart-fifo-verification) | UART RX/TX, dual FIFO, Odd Parity, error blocking | Class-based TB, mailbox, virtual interface, random stimulus, scoreboard |

## Verified Results

- **SPI UVM:** 38 PASS / 0 FAIL
- **I2C UVM:** 7 PASS / 0 FAIL
- **UART/FIFO:** random stimulus, parity-error injection, reference queue 기반 자동 비교

## Implemented Techniques

- UVM Sequence Item, Sequence, Sequencer, Driver, Monitor, Agent, Environment, Test
- Factory, Phase/Objection, Config DB 기반 virtual interface 전달
- Analysis Port/Imp 기반 Monitor → Scoreboard·Coverage 연결
- I2C ACK/NACK, Address Match, R/W, Data 및 cross functional coverage
- Class-based Transaction, Generator, Driver, Monitor, Scoreboard
- Typed mailbox, event, virtual interface 기반 component synchronization
- Queue/reference data 기반 자동 PASS/FAIL 비교
- Reset immediate assertion 및 waveform timing 분석

각 프로젝트 폴더에는 DUT, testbench, 검증 시나리오, 결과와 재현 시 주의사항을 정리했습니다.

/**
 * High-precision Game Clock & Turn Timer for Xiangqi matches.
 */

import { PieceColor } from '../engine/types.js';
import { MatchClock, TimeConfig, TimeRemainingSnapshot } from './types.js';

export type TimeoutCallback = (matchId: string, timedOutColor: PieceColor) => void;

export class ClockManager {
  private timers = new Map<string, NodeJS.Timeout>();

  /**
   * Initializes a new clock state for a match.
   */
  public createClock(timeConfig: TimeConfig): MatchClock {
    const now = Date.now();
    return {
      redBankRemainingMs: timeConfig.totalBankSeconds * 1000,
      blackBankRemainingMs: timeConfig.totalBankSeconds * 1000,
      turnLimitMs: timeConfig.turnLimitSeconds * 1000,
      turnStartTimeMs: now,
      currentTurn: 'RED',
      isRunning: false,
    };
  }

  /**
   * Starts or restarts the clock countdown for the active turn.
   */
  public startClock(matchId: string, clock: MatchClock, onTimeout: TimeoutCallback): void {
    this.stopClock(matchId);

    clock.isRunning = true;
    clock.turnStartTimeMs = Date.now();

    const currentBank =
      clock.currentTurn === 'RED'
        ? clock.redBankRemainingMs
        : clock.blackBankRemainingMs;

    // The turn ends either when the turn limit (e.g. 30s) or the total bank expires, whichever is shorter
    const timeToTimeoutMs = Math.min(clock.turnLimitMs, currentBank);

    if (timeToTimeoutMs <= 0) {
      onTimeout(matchId, clock.currentTurn);
      return;
    }

    const timer = setTimeout(() => {
      this.stopClock(matchId);
      clock.isRunning = false;
      onTimeout(matchId, clock.currentTurn);
    }, timeToTimeoutMs);

    this.timers.set(matchId, timer);
  }

  /**
   * Switches the active turn and updates elapsed banks.
   */
  public switchTurn(
    matchId: string,
    clock: MatchClock,
    nextTurn: PieceColor,
    onTimeout: TimeoutCallback
  ): void {
    const now = Date.now();
    const elapsed = Math.max(0, now - clock.turnStartTimeMs);

    // Deduct elapsed time from the player who just moved
    if (clock.currentTurn === 'RED') {
      clock.redBankRemainingMs = Math.max(0, clock.redBankRemainingMs - elapsed);
    } else {
      clock.blackBankRemainingMs = Math.max(0, clock.blackBankRemainingMs - elapsed);
    }

    clock.currentTurn = nextTurn;
    clock.turnStartTimeMs = now;

    if (clock.isRunning) {
      this.startClock(matchId, clock, onTimeout);
    }
  }

  /**
   * Calculates a current snapshot of remaining time without mutating state.
   */
  public getTimeRemainingSnapshot(clock: MatchClock): TimeRemainingSnapshot {
    const now = Date.now();
    const elapsed = clock.isRunning ? Math.max(0, now - clock.turnStartTimeMs) : 0;

    let redBank = clock.redBankRemainingMs;
    let blackBank = clock.blackBankRemainingMs;

    if (clock.isRunning) {
      if (clock.currentTurn === 'RED') {
        redBank = Math.max(0, redBank - elapsed);
      } else {
        blackBank = Math.max(0, blackBank - elapsed);
      }
    }

    const currentTurnTimeRemainingMs = clock.isRunning
      ? Math.max(0, clock.turnLimitMs - elapsed)
      : clock.turnLimitMs;

    return {
      redTimeRemainingMs: redBank,
      blackTimeRemainingMs: blackBank,
      currentTurnTimeRemainingMs,
    };
  }

  /**
   * Stops and clears the timer for a match.
   */
  public stopClock(matchId: string): void {
    const timer = this.timers.get(matchId);
    if (timer) {
      clearTimeout(timer);
      this.timers.delete(matchId);
    }
  }

  /**
   * Cleanup all timers.
   */
  public clearAll(): void {
    for (const timer of this.timers.values()) {
      clearTimeout(timer);
    }
    this.timers.clear();
  }
}

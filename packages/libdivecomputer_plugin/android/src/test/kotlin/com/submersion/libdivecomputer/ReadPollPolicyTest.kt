package com.submersion.libdivecomputer

import com.submersion.libdivecomputer.ReadPollPolicy.Action
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// JVM tests for the read-poll decisions behind BleIoStream's read mode
// (issue #1454). Mirrors darwin/Tests/ReadPollPolicyTests case for case.
class ReadPollPolicyTest {

    @Test
    fun idleIssuesOneReadThenWaitsWhileItIsInFlight() {
        val policy = ReadPollPolicy()
        assertEquals(Action.ISSUE_READ, policy.next(0))
        assertTrue(policy.readInFlight)
        assertEquals(Action.WAIT, policy.next(5))
        assertEquals(Action.WAIT, policy.next(10_000))
    }

    @Test
    fun dataIsQueuedAndTheNextReadGoesOutAtOnce() {
        val policy = ReadPollPolicy()
        policy.next(0)
        assertTrue(policy.completed(hasData = true, nowMs = 50))
        assertEquals(Action.ISSUE_READ, policy.next(50))
    }

    @Test
    fun emptyValueBacksOffBeforeRereading() {
        val policy = ReadPollPolicy()
        policy.next(0)
        assertFalse(policy.completed(hasData = false, nowMs = 1000))
        assertEquals(Action.WAIT, policy.next(1099))
        assertEquals(Action.ISSUE_READ, policy.next(1100))
    }

    @Test
    fun refusedIssueBacksOff() {
        val policy = ReadPollPolicy()
        assertEquals(Action.ISSUE_READ, policy.next(0))
        policy.issueFailed(0)
        assertFalse(policy.readInFlight)
        assertEquals(Action.WAIT, policy.next(99))
        assertEquals(Action.ISSUE_READ, policy.next(100))
    }

    @Test
    fun purgeWhileInFlightDiscardsTheLateValue() {
        val policy = ReadPollPolicy()
        policy.next(0)
        policy.purge()
        assertFalse(policy.completed(hasData = true, nowMs = 500))
        assertEquals(Action.ISSUE_READ, policy.next(500))
        assertTrue(policy.completed(hasData = true, nowMs = 600))
    }

    @Test
    fun purgeWhileIdleDiscardsNothingLater() {
        val policy = ReadPollPolicy()
        policy.purge()
        policy.next(0)
        assertTrue(policy.completed(hasData = true, nowMs = 10))
    }

    @Test
    fun discardedEmptyValueDoesNotBackOff() {
        val policy = ReadPollPolicy()
        policy.next(0)
        policy.purge()
        assertFalse(policy.completed(hasData = false, nowMs = 500))
        assertEquals(Action.ISSUE_READ, policy.next(500))
    }

    @Test
    fun closeFailsReadsAndIgnoresLateCompletions() {
        val policy = ReadPollPolicy()
        policy.next(0)
        policy.close()
        assertEquals(Action.CLOSED, policy.next(1))
        assertFalse(policy.completed(hasData = true, nowMs = 2))
        assertEquals(Action.CLOSED, policy.next(3))
    }

    // A device that answers every read with an empty value, polled every
    // millisecond for libdivecomputer's 6000 ms: one read per retry delay.
    @Test
    fun emptyValuesUntilTheDeadlineNeverSpin() {
        val policy = ReadPollPolicy()
        var issued = 0
        for (now in 0L until 6000L) {
            if (policy.next(now) == Action.ISSUE_READ) {
                issued++
                policy.completed(hasData = false, nowMs = now)
            }
        }
        assertEquals(60, issued)
    }

    // System.nanoTime() is allowed to be negative, and the clock BleIoStream
    // feeds in derives from it. A fresh policy must still issue at once.
    @Test
    fun negativeClockStillIssuesImmediately() {
        val policy = ReadPollPolicy()
        assertEquals(Action.ISSUE_READ, policy.next(-5_000_000L))
    }
}

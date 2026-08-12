package thumb

import (
	"testing"
	"time"
)

func TestQueueCreation(t *testing.T) {
	q := NewQueue(5)
	if q == nil {
		t.Fatal("queue should not be nil")
	}
	if q.ch == nil {
		t.Fatal("queue channel should not be nil")
	}
	// Submit a dummy job to ensure the queue works
	done := make(chan bool, 1)
	q.Submit(Job{
		PhotoID:   1,
		InputPath: "/nonexistent",
		OutputDir: t.TempDir(),
		OnDone: func(photoID int64, thumbPath string, err error) {
			done <- true
		},
	})
	// The job will fail (nonexistent file) but should still call OnDone
	select {
	case <-done:
		// good
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for job completion")
	}
	q.Close()
}

package thumb

import (
	"fmt"
	"log"
	"os/exec"
	"path/filepath"
	"sync"
)

type Job struct {
	PhotoID   int64
	InputPath string
	OutputDir string
	OnDone    func(photoID int64, thumbPath string, err error)
}

type Queue struct {
	ch chan Job
	wg sync.WaitGroup
}

func NewQueue(size int) *Queue {
	q := &Queue{
		ch: make(chan Job, size),
	}
	q.wg.Add(1)
	go q.worker()
	return q
}

func (q *Queue) worker() {
	defer q.wg.Done()
	for job := range q.ch {
		q.process(job)
	}
}

func (q *Queue) process(job Job) {
	outputPath := filepath.Join(job.OutputDir, fmt.Sprintf("%d.jpg", job.PhotoID))

	cmd := exec.Command("vipsthumbnail",
		job.InputPath,
		"-s", "400",
		"-o", outputPath,
		"--format", "jpeg",
	)
	err := cmd.Run()
	if err != nil {
		log.Printf("thumb: vipsthumbnail failed for photo %d: %v", job.PhotoID, err)
		if job.OnDone != nil {
			job.OnDone(job.PhotoID, "", err)
		}
		return
	}
	if job.OnDone != nil {
		job.OnDone(job.PhotoID, outputPath, nil)
	}
}

func (q *Queue) Submit(job Job) {
	q.ch <- job
}

func (q *Queue) Close() {
	close(q.ch)
	q.wg.Wait()
}

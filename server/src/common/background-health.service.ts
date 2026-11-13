import { Injectable } from "@nestjs/common";

/** Process-local readiness for the workers running inside this API instance. */
@Injectable()
export class BackgroundHealthService {
  private readonly tasks = new Map<
    string,
    { lastSuccess: number; maxAge: number; failed: boolean }
  >();
  register(name: string, maxAge: number) {
    this.tasks.set(name, { lastSuccess: Date.now(), maxAge, failed: false });
  }
  success(name: string) {
    const task = this.tasks.get(name);
    if (task) {
      task.lastSuccess = Date.now();
      task.failed = false;
    }
  }
  failure(name: string) {
    const task = this.tasks.get(name);
    if (task) task.failed = true;
  }
  remove(name: string) {
    this.tasks.delete(name);
  }
  isHealthy(name: string) {
    const task = this.tasks.get(name);
    return (
      !task || (!task.failed && Date.now() - task.lastSuccess <= task.maxAge)
    );
  }
  snapshot() {
    return Object.fromEntries(
      [...this.tasks].map(([name, task]) => [
        name,
        this.isHealthy(name)
          ? { status: "up" as const }
          : {
              status: "down" as const,
              reason: task.failed
                ? ("unavailable" as const)
                : ("stale" as const),
            },
      ]),
    );
  }
}

<?php
// Lamma - by Mohamed Ibrahim

namespace App\Console\Commands;

use App\Jobs\ReplenishContentStockJob;
use Illuminate\Console\Command;

class ReplenishContentCommand extends Command
{
    protected $signature = 'content:replenish {--type=all} {--category=} {--difficulty=medium}';
    protected $description = 'تشغيل وظيفة فحص وتعويض المخزون تلقائياً بالذكاء الاصطناعي';

    public function handle(): int
    {
        $type = (string) $this->option('type');
        $cat = (string) $this->option('category');
        $diff = (string) $this->option('difficulty');

        $this->info("Dispatching ReplenishContentStockJob for [{$type}]...");
        ReplenishContentStockJob::dispatchSync($type, !empty($cat) ? $cat : null, $diff);

        $this->info("Replenishment completed successfully.");
        return 0;
    }
}

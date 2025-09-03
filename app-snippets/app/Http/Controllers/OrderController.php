<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use App\Jobs\ProcessOrder;
use Illuminate\Support\Str;

class OrderController extends Controller
{
    public function store(Request $request)
    {
        $request->validate([
            'file' => 'required|file|mimes:jpg,jpeg,png,pdf',
        ]);

        // Minimal "order" ID (replace with a real model in src/)
        $orderId = random_int(1000, 9999);

        $file = $request->file('file');
        $key = 'uploads/' . Str::uuid() . '/' . 
$file->getClientOriginalName();

        // Use default filesystem disk (local for dev)
        Storage::disk(config('filesystems.default'))->put($key, 
file_get_contents($file));

        // Queue async processing
        ProcessOrder::dispatch($orderId);

        return response()->json([
            'order_id' => $orderId,
            'file_key' => $key,
            'status'   => 'queued'
        ], 201);
    }

    public function ready()
    {
        // Simple health endpoint; expand to check DB/SQS/S3 as needed
        return response()->json(['status' => 'ready'], 200);
    }
}

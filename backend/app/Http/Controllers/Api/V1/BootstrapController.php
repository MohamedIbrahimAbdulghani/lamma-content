<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\AvatarResource;
use App\Http\Resources\CategoryResource;
use App\Http\Resources\CharadesCategoryResource;
use App\Http\Resources\RulePageResource;
use App\Http\Resources\SpyWordPackResource;
use App\Models\AppSetting;
use App\Models\Avatar;
use App\Models\Category;
use App\Models\CharadesCategory;
use App\Models\ContentVersion;
use App\Models\RulePage;
use App\Models\SpyWordPack;
use Illuminate\Http\JsonResponse;

class BootstrapController extends Controller
{
    public function bootstrap(): JsonResponse
    {
        $currentVersion = ContentVersion::current();
        $version = $currentVersion?->version ?? 1;
        $lastUpdated = $currentVersion?->generated_at?->toIso8601String() ?? now()->toIso8601String();

        $categories = Category::where('is_active', true)->orderBy('sort_order')->get();
        $spyPacks = SpyWordPack::with(['words' => fn ($q) => $q->where('is_active', true)])->get();
        $charadesCategories = CharadesCategory::with(['words' => fn ($q) => $q->where('is_active', true)])->get();
        $avatars = Avatar::orderBy('sort_order')->get();
        $rulePages = RulePage::all();
        $settings = AppSetting::pluck('value', 'key')->all();

        return response()->json([
            'version' => $version,
            'last_updated' => $lastUpdated,
            'categories' => CategoryResource::collection($categories),
            'spy' => [
                'packs' => SpyWordPackResource::collection($spyPacks),
            ],
            'charades' => [
                'categories' => CharadesCategoryResource::collection($charadesCategories),
            ],
            'avatars' => AvatarResource::collection($avatars),
            'rule_pages' => RulePageResource::collection($rulePages),
            'settings' => $settings,
        ]);
    }

    public function version(): JsonResponse
    {
        $currentVersion = ContentVersion::current();
        $version = $currentVersion?->version ?? 1;
        $lastUpdated = $currentVersion?->generated_at?->toIso8601String() ?? now()->toIso8601String();

        return response()->json([
            'version' => $version,
            'last_updated' => $lastUpdated,
        ]);
    }
}

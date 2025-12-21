# 秘書型習慣形成AIアシスタントアプリ — 完全仕様書

## 1. アプリの本質的なコンセプト

ユーザーの日常アクション（タスク完了、時間経過、特定の状況）をトリガーとして、生成AIが文脈を理解して「次に取るべき行動」を提案・促進する秘書的アシスタント。

RDBベースの厳密なタスク管理ではなく、自由記述とAI会話を中心とした、より自然で柔軟な習慣形成サポート。

初期段階はフィードバックループを頻繁に回しながら、ユーザー独自の秘書を育成する。利用データに基づいて継続的に Onboarding を更新可能。

---

## 2. コアデータモデル

### 2.1 Habit（習慣）- 改良版

```
Habit:
├─ id (UUID)
├─ userId (外部キー)
├─ name (string) 
│  例: "ピアノの練習", "朝食", "皿を片付ける"
├─ description (text)
├─ targetFrequency (enum)
│  値: "daily", "weekly_3times", "weekly_5times", "custom"
├─ parentHabitId (UUID, nullable)
│  階層化用：親習慣のID。nullなら根習慣
├─ level (integer)
│  0=根習慣, 1=子習慣, 2以上=さらに深い階層
├─ internalPrompt (text)
│  AIに対する初期プロンプト
│  例: "ピアノの練習をする際は『電源を入れる』ことから始まる。
│       最小限の一歩でも励ましてほしい"
├─ completionLogic (JSON object)
│  このHabitが「完了」と判定される条件
│  例: {
│    "type": "all_steps" | "any_step" | "percentage_threshold",
│    "value": 100 | 50 | ...
│  }
│
│ 【新規追加：重要度関連】
│
├─ importance (integer 1-5)
│  ユーザーが明示的に指定した重要度（通常は直接入力なし）
│  1=できたらいい, 2=やった方がいい, 3=中程度, 4=重要, 5=非常に重要
│  
├─ importanceInferred (float 0-1)
│  Onboarding対話から「推測された」重要度
│  抽出ロジック例：
│  - ユーザーが「絶対やりたい」「必須」と言及 → 0.9-1.0
│  - 「できればやりたい」「可能なら」と言及 → 0.5-0.7
│  - 「あればいい」という言及 → 0.3-0.5
│  - 明記なし → 0.5（中立）
│
├─ importanceSource (enum)
│  "explicit"（ユーザーが明示指定）| "inferred"（対話から推測）
│
├─ hiddenParameters (JSON object)
│  Onboarding対話から自動抽出された「隠しパラメータ」
│  {
│    "rigidityLevel": 0-1,
│      // 習慣の柔軟性。1に近いほど「絶対にやる」「融通が利かない」
│      // 推測例：「毎日必ず」→ 0.9
│      //        「可能なら」→ 0.3
│
│    "contextualTriggers": ["子どもが寝た後", "朝の時間"],
│      // この習慣のトリガーになると言及されたコンテキスト
│
│    "seasonalVariation": boolean,
│      // 「平日は」「冬は」など、季節・曜日依存性の有無
│      // 推測例：「平日は毎日」と言及 → true
│
│    "conflictingHabits": ["習慣ID-1", "習慣ID-2"],
│      // この習慣と競合する可能性のある他の習慣
│      // 推測例：「朝時間がない」→「ストレッチ」と「朝勉強」が競合
│
│    "toleranceForFailure": 0-1,
│      // ユーザーが失敗・未実行をどの程度許容するか
│      // 推測例：「できればいい」→ 0.8
│      //        「絶対やるべき」→ 0.2
│
│    "emotionalSignificance": 0-1,
│      // 習慣に対する感情的な重要性
│      // 推測例：「ピアノが大好き」と語られた → 0.9
│      //        「子どものためにやる」と語られた → 0.8
│      //        「健康的だから」と語られた → 0.6
│
│    "userRealisticExpectation": 0-1,
│      // ユーザーが現実的な期待を持っているか
│      // 推測例：「時間が短いので難しい」と自覚 → 0.7（現実的）
│      //        「毎日完璧にやる」と理想化 → 0.3（非現実的）
│
│    "externalPressure": 0-1,
│      // 外部からの圧力があるか（家族、仕事など）
│      // 推測例：「子どものために」→ 0.7
│      //        「自分がしたい」 → 0.2
│
│    "existingMomentum": 0-1,
│      // その習慣が既に形成されているか（新規か既存か）
│      // 推測例：「今もやってる」と言及 → 0.8
│      //        「やってない」「新しく始めたい」 → 0.2
│  }
│
├─ createdAt (timestamp)
├─ updatedAt (timestamp)
└─ isArchived (boolean)
```

### 2.2 HabitStep（習慣の実行ステップ）

```
HabitStep:
├─ id (UUID)
├─ habitId (外部キー)
├─ stepNumber (integer)
│  実行順序。1が最初のステップ
├─ description (string)
│  例: "ピアノの電源を入れる", "ウォーミングアップ"
├─ difficulty (float 0-1)
│  実行難度。0=非常に簡単, 1=難しい
├─ estimatedTimeMinutes (integer)
│  想定される実行時間（分）
├─ isMinimalStep (boolean)
│  このステップが「最初の一歩」を構成するか
│  多くの場合、stepNumber=1 と一致するが、必ずしもそうではない
├─ generatedBy (enum)
│  "userDefined" | "aiGenerated"
├─ createdAt (timestamp)
└─ updatedAt (timestamp)
```

### 2.3 HabitChain（習慣チェーン関係）

```
HabitChain:
├─ id (UUID)
├─ userId (外部キー)
├─ triggerHabits (array of UUID)
│  このチェーンを発火させるHabitIDの配列
│  複数指定可能（AND/OR条件で処理）
├─ nextHabitId (UUID)
│  トリガーされるHabitのID
├─ delayMinutes (integer, default=0)
│  triggerが完了してから、nextHabitを提案するまでの遅延時間
│
│ 【新規追加】prerequisiteHabits (array of objects)
│  このチェーンの実行に先立って必須の習慣
│  [
│    {
│      "habitId": "move-table-001",
│      "habitName": "居間の机をどかす",
│      "chainType": "prerequisite",
│      "isMandatory": true,
│      "frequency": "毎回",
│      "estimatedTimeMinutes": 5
│    }
│  ]
│
├─ triggerCondition (JSON object)
│  チェーン発火条件の詳細
│  {
│    "type": "timeAfter" | "allTriggersCompleted" | "anyTriggerCompleted" 
│           | "prerequisite_completed",
│    "details": {...}  // typeに応じた詳細
│  }
├─ isAutomatic (boolean)
│  true=AIが学習で発見したパターン
│  false=ユーザーが明示的に定義
├─ confidence (float 0-1)
│  AIが学習したパターンの信頼度
│  ユーザー定義の場合は 1.0
├─ frequency (integer)
│  このチェーンが実行された実績回数
├─ createdAt (timestamp)
├─ updatedAt (timestamp)
└─ isActive (boolean)
```

### 2.4 TriggerCondition（チェーン発火条件の詳細）

```
TriggerCondition examples:

1. 時間ベース:
{
  "type": "timeAfter",
  "delayMinutes": 15
}

2. 複数トリガーのAND（すべてが必要）:
{
  "type": "allTriggersCompleted",
  "requireAll": true,
  "delayMinutes": 30  // 最後のトリガーから
}

3. 複数トリガーのOR（いずれか1つ）:
{
  "type": "anyTriggerCompleted",
  "delayMinutes": 5
}

4. 複合条件（AIが学習可能な形式）:
{
  "type": "customLogic",
  "condition": "triggerHabits[0] AND triggerHabits[1] completed within 30min",
  "delayMinutes": 10
}
```

### 2.5 HabitExecution（習慣実行ログ）

```
HabitExecution:
├─ id (UUID)
├─ userId (外部キー)
├─ habitId (UUID, 外部キー)
├─ stepId (UUID, nullable)
│  特定のHabitStepの完了を記録する場合
├─ completedAt (timestamp)
│  実行日時
├─ reportedVia (enum)
│  "directMessage" | "aiInference" | "autoDetected"
│  ユーザーが明示的に報告したか、AIが推測したか、システムが自動検出したか
├─ messageId (UUID, 外部キー)
│  このExecutionの根拠となったメッセージID
├─ executionType (enum)
│  "direct" | "inferred" | "partial"
│  directは100%完了、inferredは文脈から推測された完全完了、
│  partialは部分完了
├─ completionPercentage (integer 0-100)
│  習慣の完了度
│  executionType="direct" なら常に100
├─ daysChain (integer)
│  連続実行日数（ハビット・チェーン）
├─ createdAt (timestamp)
└─ isCorrected (boolean)
   ユーザーが後で修正/取り消した場合
```

### 2.6 ExecutionInference（AI判定ログ）

```
ExecutionInference:
├─ id (UUID)
├─ userId (外部キー)
├─ messageId (UUID, 外部キー)
│  参照するメッセージ
├─ userInput (text)
│  ユーザーが入力したテキスト
│  例: "ウォーミングアップをやった"
├─ inferredHabits (JSON array)
│  AIが推測した関連習慣
│  [
│    {
│      "habitId": "xxx",
│      "executionType": "direct" | "partial" | "inferred",
│      "completionPercentage": 100 | 50 | 33,
│      "reasoning": "このステップはOnboarding時に3ステップ中1番目と記録されている"
│    },
│    ...
│  ]
├─ chainConsistencyCheck (JSON object)
│  定義されたHabitChain と実際の報告の整合性を検査
│  {
│    "detectedChain": ["朝7時起床", "コーヒーボタンON", "子ども朝ごはん準備"],
│    "expectedChain": ["朝7時起床", "洗顔・身だしなみ", "コーヒーボタンON", 
│                      "ストレッチ（軽く）", "子ども朝ごはん準備"],
│    "skippedSteps": [
│      {
│        "habitId": "washing-001",
│        "habitName": "洗顔・身だしなみ",
│        "expectedPosition": 2,
│        "priority": "high",
│        "question": "洗顔はされましたか？"
│      }
│    ],
│    "unreportedSteps": [
│      {
│        "habitId": "stretch-001",
│        "habitName": "ストレッチ（軽く）",
│        "expectedPosition": 4,
│        "priority": "low",
│        "question": "ストレッチはされましたか？"
│      }
│    ],
│    "inconsistencyLevel": 0.4,
│    "recommendedAction": "clarify"
│  }
│
├─ proactiveQuestions (JSON object)
│  【修正】日常利用とOnboarding 両方の質問セットを含む
│  {
│    "dailyUse": {
│      "simple": "洗顔はしましたか？ またストレッチはしましたか？",
│      "splitSimple": [
│        "洗顔はしましたか？",
│        "ストレッチはしましたか？"
│      ]
│    },
│    "onboardingPhase": {
│      "priority1": [
│        {
│          "habitId": "washing-001",
│          "habitName": "洗顔・身だしなみ",
│          "shortQuestion": "洗顔はしましたか？",
│          "detailedQuestions": [
│            "洗顔をしなかった理由は何ですか？",
│            "朝の時間が足りなかったのか、それとも習慣として定着していないのか？",
│            "洗顔は今後も習慣として含めたいですか、それとも削除したいですか？",
│            "もし続けたい場合、何か工夫が必要ですか？（例：時間短縮、別の時間帯など）"
│          ],
│          "context": "Onboarding で importanceInferred=0.55 と中程度の重要度だが、
│                     実際には実行されていない。理由を把握する必要がある。"
│        }
│      ],
│      "priority2": [
│        {
│          "habitId": "stretch-001",
│          "habitName": "ストレッチ（軽く）",
│          "shortQuestion": "ストレッチはしましたか？",
│          "detailedQuestions": [
│            "ストレッチはしなかった理由は何ですか？",
│            "『できればやりたい』という位置付けですが、実際にはやる余裕がありませんか？",
│            "もし続けたい場合、時間帯や内容を工夫できることはありますか？",
│            "それとも、朝のルーティンから削除して別の時間帯でやることを検討しますか？"
│          ],
│          "context": "Onboarding で importanceInferred=0.35 と低い重要度。
│                     toleranceForFailure=0.8 と高く、失敗許容度が高い習慣だが、
│                     実際の実行状況を確認する。"
│        }
│      ]
│    }
│  }
├─ userFeedback (JSON object, nullable)
│  ユーザーが判定の正誤を評価した結果
│  {
│    "isCorrect": boolean,
│    "correctionType": "minor" | "major",
│    "correctedInference": [{...}],
│    "userExplanation": "実は洗顔はしたが報告し忘れていた",
│    "feedbackAt": timestamp
│  }
├─ debugInfo (JSON object)
│  debugMode=true の場合のみ生成・表示
│  {
│    "modelConfidence": 0.75,
│    "chainAnalysis": {
│      "expectedChainId": "morning-chain-001",
│      "detectedSequence": ["起床", "コーヒー", "朝食"],
│      "divergence": ["洗顔スキップ", "ストレッチ未報告"],
│      "possibleExplanations": [
│        "ユーザーが忙しくて洗顔をスキップ",
│        "洗顔はしたが報告し忘れ",
│        "朝の習慣の順序が実際には違う"
│      ]
│    },
│    "similarPastCases": [...]
│  }
├─ aiLearningApplied (JSON object)
│  このフィードバックから何を学習したか
│  {
│    "modelUpdated": true,
│    "changes": ["洗顔の重要度を0.55 → 0.45に下方修正（ユーザーがスキップしがちなため）"]
│  }
├─ createdAt (timestamp)
└─ updatedAt (timestamp)
```

### 2.7 Message（会話ログ）

```
Message:
├─ id (UUID)
├─ userId (外部キー)
├─ conversationId (UUID)
│  会話セッションのID
├─ sender (enum)
│  "user" | "assistant"
├─ content (text)
│  メッセージ本体
├─ relatedHabits (array of UUID, nullable)
│  このメッセージから自動抽出された関連HabitID群
├─ relatedChains (array of UUID, nullable)
│  このメッセージから自動抽出された関連HabitChainID群
├─ createdAt (timestamp)
└─ metadata (JSON object, optional)
   追加のコンテキスト情報
```

### 2.8 Interview（Onboarding記録）

```
Interview:
├─ id (UUID)
├─ userId (外部キー)
├─ versionNumber (integer)
│  Onboardingが何度更新されたか（1, 2, 3, ...）
├─ sessionType (enum)
│  "initial" | "incremental" | "review"
│  initial: アプリ初回起動時の最小限Onboarding
│  incremental: 継続的な追加インタビュー
│  review: 利用データに基づく定期更新
├─ interviewSequence (array of objects)
│  [
│    {
│      "order": 1,
│      "aiQuestion": "こんにちは。朝は何時に起きますか？",
│      "userAnswer": "6時です",
│      "extractedData": {
│        "mentionedHabits": ["起床"],
│        "temporalInfo": ["6時"],
│        "triggers": [],
│        "dependencies": []
│      },
│      "proposedHabits": ["xxx-id"],
│      "timestamp": timestamp
│    },
│    ...
│  ]
├─ generatedHabits (array of UUID)
│  このInterviewから生成されたHabitのリスト
├─ generatedChains (array of UUID)
│  このInterviewから生成されたHabitChainのリスト
├─ summary (text)
│  このInterviewセッションの要約
│  例: "朝のルーティン、ピアノの練習（夜）、食事後の片付けを習慣化したい"
├─ startedAt (timestamp)
├─ completedAt (timestamp, nullable)
├─ isActive (boolean)
│  このバージョンのOnboardingが現在有効か
├─ plannedFollowUp (timestamp, nullable)
│  次のインクリメンタルOnboardingを予定している日時
├─ completionPercentage (integer 0-100)
│  このOnboardingセッションの完了度
│  100%でなくても、最小限の習慣が1つ以上定義されれば、
│  アプリの利用を開始できる設計
└─ readyForUsage (boolean)
   ユーザーがアプリを使い始めるのに十分な習慣が定義されたか
```

### 2.9 InterviewUpdate（Onboarding更新提案）

```
InterviewUpdate:
├─ id (UUID)
├─ userId (外部キー)
├─ currentInterviewVersion (integer)
│  参照している現在のInterviewバージョン
├─ proposedChanges (JSON object)
│  {
│    "archivedHabits": [
│      {
│        "habitId": "xxx",
│        "reason": "3週間実行がない",
│        "suggestion": "「朝食」は習慣づけられた可能性"
│      }
│    ],
│    "newObservedPatterns": [
│      {
│        "description": "「昼食」の後、常に『皿を片付ける』をしている",
│        "suggestedNewHabit": null,  // 既知の場合
│        "suggestedChain": {
│          "triggerHabit": "昼食",
│          "nextHabit": "皿を片付ける",
│          "confidence": 0.95
│        }
│      }
│    ],
│    "questionsForUser": [
│      "『皿を片付ける』習慣は『朝食』『昼食』『夕食』すべての後にやるのか、
        それとも特定の食事の後だけか？"
│    ]
│  }
├─ userApprovalStatus (enum)
│  "pending" | "approved" | "rejected" | "partially_approved"
├─ userFeedback (text, nullable)
│  ユーザーの回答や追加情報
├─ appliedAt (timestamp, nullable)
│  更新が適用された日時
└─ createdAt (timestamp)
```

### 2.10 OnboardingExtraction（Onboarding対話からの自動抽出）

```
OnboardingExtraction:
├─ id (UUID)
├─ interviewId (外部キー)
├─ habitId (外部キー)
├─ originalQuestion (text)
│  AIが聞いた質問
│  例: "では、朝起床後、最初にすることは何ですか？"
├─ originalAnswer (text)
│  ユーザーが答えたテキスト
│  例: "朝6時に起きて、すぐにコーヒーを入れて、子どもの朝ごはんを準備しています。
│       本当は洗顔をしたりなど、身だしなみの観点で正しい行動を追加したいと思っていました。"
├─ extractedConcepts (JSON array)
│  対話から抽出されたコンセプト
│  [
│    {
│      "concept": "習慣名",
│      "keyword": "朝起床",
│      "context": "朝6時に起きて"
│    },
│    {
│      "concept": "トリガー",
│      "keyword": "すぐに",
│      "context": "起きてすぐにコーヒーを入れて"
│    },
│    ...
│  ]
├─ inferredImportance (float 0-1)
│  重要度推測値
│  計算ロジック例：
│    - 「必ず」「絶対に」→ +0.3
│    - 「できれば」「可能なら」→ +0.1
│    - 「〜したい」という願望表現 → +0.15
│    - 「本当は」という後悔表現 → +0.2
│    - 「今もやってる」という既存性 → +0.1
│    - 基準値 0.5 に加算
├─ inferredHiddenParameters (JSON object)
│  隠しパラメータの推測値
│  {
│    "rigidityLevel": 計算例：「毎日」「必ず」など絶対表現 → 0.9
│                           「できれば」「可能なら」など条件付き → 0.4
│                           
│    "contextualTriggers": ["朝起床時", "子どもの朝ごはん後"],
│    
│    "seasonalVariation": 判定例：「平日は」と言及 → true
│    
│    "conflictingHabits": 推測例：「朝時間がない」→
│                                 "朝ストレッチ" と "朝勉強" が競合
│    
│    "toleranceForFailure": 判定例：「難しい」「うまくいかない」と言及 → 0.7
│                                   「絶対やる」と言及 → 0.2
│    
│    "emotionalSignificance": 判定例：「好き」「楽しい」など正感情 → 0.8
│                                     「やらなきゃ」という義務感 → 0.5
│                                     「子どものため」という他者志向 → 0.7
│    
│    "userRealisticExpectation": 判定例：「時間が短いから難しい」と自覚 → 0.75
│                                       「毎日完璧に」と理想化 → 0.3
│    
│    "externalPressure": 判定例：「子ども送迎のため」→ 0.8
│                               「自分がしたい」→ 0.2
│    
│    "existingMomentum": 判定例：「今もやってる」「既に習慣」→ 0.8
│                               「新しく始めたい」「できていない」 → 0.2
│  }
├─ confidenceScore (float 0-1)
│  この抽出結果の信頼度
│  例：明示的な語句が多い → 0.9
│      曖昧な推測 → 0.5
├─ timestamp (timestamp)
└─ notes (text, optional)
   抽出のメモ。例：「『本当は』という後悔表現から、
                   この習慣に対する願望が強いと推測」
```

---

### Onboarding対話から隠しパラメータを推測するロジック（具体例）

**Akiraの対話から：**

```
AI: 「朝は何時に起きて、起床後、最初にすることは何ですか？」

User: 「平日は7時30分から8時までに起きて、子どもの登園の準備をします。
       具体的には自分用にコーヒーを入れて、子どもの朝ごはんを準備しています。
       本当は洗顔をしたりなど、身だしなみの観点で正しい行動を追加したいと思っていました。」

↓ 抽出ロジック：

HabitA: 朝7時30分～8時起床
  - importanceInferred: 0.7
    理由：「平日は」と習慣性を示唆 (+0.15)
         「子どもの登園準備のため」と外部圧力 (+0.15)
         現在既に実行している (+0.1)
         基準値 0.5 + 0.4 = 0.9 だが、「できればもっと早く」という含みがあるため 0.7
  
  - hiddenParameters:
    rigidityLevel: 0.8
      理由：「平日は」と絶対的な表現
    
    contextualTriggers: ["子どもの登園準備が必要になる時刻"]
    
    seasonalVariation: true
      理由：「平日は」と明示
    
    toleranceForFailure: 0.3
      理由：外部の制約（子ども送迎）があり、失敗が許されない
    
    emotionalSignificance: 0.6
      理由：「子どもの準備」という責務的
    
    userRealisticExpectation: 0.8
      理由：現在実行している＆具体的な時間を認識
    
    externalPressure: 0.85
      理由：「子どもの登園」という強い外部制約
    
    existingMomentum: 0.85
      理由：「今もやっている」という既存習慣

HabitB: コーヒーを入れる
  - importanceInferred: 0.65
    理由：「自分用に」という自分志向だが必須アクション
    
  - hiddenParameters:
    rigidityLevel: 0.7
      理由：起床直後の必須アクション
    
    emotionalSignificance: 0.7
      理由：「自分用」という自分へのご褒美的な意味合い

HabitC: 子どもの朝ごはん準備
  - importanceInferred: 0.95
    理由：「具体的に実施している」→ +0.1
         「登園準備の必須要素」→ +0.2
         「子どものため」という強い外部圧力 → +0.3
         基準値 0.5 + 0.6 = 1.0 だが、自然さで 0.95
  
  - hiddenParameters:
    rigidityLevel: 0.95
      理由：子どもの栄養・生命に関わる必須タスク
    
    toleranceForFailure: 0.05
      理由：子どものため、失敗が許されない
    
    externalPressure: 0.95
      理由：子どもの健康と送迎という強力な外部制約
    
    emotionalSignificance: 0.9
      理由：子どものケアとしての親の責務

HabitD: 洗顔・身だしなみ
  - importanceInferred: 0.55
    理由：「本当は〜したいと思っていた」という願望表現 (+0.2)
         「正しい行動を追加したい」という理想化 (+0.15)
         しかし「できていない」現状 (-0.1)
         基準値 0.5 + 0.25 = 0.75 だが、実行されていない現実から 0.55
  
  - hiddenParameters:
    rigidityLevel: 0.4
      理由：「できればやりたい」という弱い表現
    
    toleranceForFailure: 0.7
      理由：身だしなみは「やるべき」が「できたら」レベル
    
    userRealisticExpectation: 0.5
      理由：「朝時間がない」と暗に認識しながら「追加したい」と願望
           → 非現実的な期待の可能性
    
    emotionalSignificance: 0.4
      理由：「正しい行動」という道徳的な理由（自分の本音ではない可能性）
```

**このロジックにより：**

- Akiraは、子ども関連の習慣（朝ごはん準備）を **最優先度** として設定すべき
- 洗顔・身だしなみは、**現実的な期待値を下げるべき** （「完全にやる」ではなく「できたらで良い」）
- ストレッチや朝勉強は、**時間がない場合はカットしても良い** という判定が可能
- 夜のアイドル配信習慣は、**重要度は高い（感情的）** だが、**睡眠との競合がある** という認識が必要

---

## 3. アプリケーションモードの定義

### 3.0 3つのモード概要

アプリは3つの異なるモードで動作します：

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  実行モード          Onboarding モード     レポートモード│
│  ┌──────────┐      ┌──────────┐         ┌──────────┐  │
│  │          │      │          │         │          │  │
│  │ 現在進行  │  →  │ 習慣の最適化│ ←   │ 進捗分析  │  │
│  │ 中のタスク│      │ と設定更新 │       │ とレポート│  │
│  │          │      │          │         │          │  │
│  └──────────┘      └──────────┘         └──────────┘  │
│       ↑                                        ↑        │
│       │ ユーザー入力                          │        │
│       └────────────────────────────────────────┘        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 3.0.1 実行モード（Execution Mode）

**目的**：ユーザーが現在進行中のタスクを報告し、AI が即座に対応する。

**特徴**：
- リアルタイム処理
- ユーザーの報告に対して、即座に応答
- 習慣のチェーン整合性を確認
- 必要に応じて、Onboarding モードへの質問をキューに追加
- ただし、詳細な習慣再検討は行わない（それは Onboarding モード）

**実行モードでの処理フロー**：

```
ユーザー報告
  ↓
[NLP解析 - タスク vs 習慣の判定]
  ↓
IF 報告内容が「既知の習慣」に該当
  → 習慣として記録（HabitExecution）
  → ExecutionInference で推測判定
  → チェーン整合性を確認
  → 必要なら次のアクションを提案
  ↓
ELSE IF 報告内容が「単発のタスク」（習慣ではない）
  → タスクとして記録（Task レコード）
  → レポートモード用に保存
  → Onboarding モードには提案しない
  ↓
AI応答（シンプルに）
  ↓
[Onboarding モード用の質問があれば、キューに追加]
```

**【新規追加】Task（単発タスク）データモデル**

```
Task:
├─ id (UUID)
├─ userId (外部キー)
├─ messageId (外部キー)
│  この報告の根拠となったメッセージ
├─ name (string)
│  例: 「パッカーズ vs ベアーズ観戦」「朝食」（単発）
├─ description (text)
│  「今日はそれを見ながら自分の朝食を食べて、あとでストレッチをしよう」
├─ taskType (enum)
│  "occasional"（単発）| "contextual"（文脈的・その場限りの）
├─ relatedHabits (array of UUID)
│  このタスクと関連する習慣（例：「朝食」習慣）
│  ただし、タスク自体は習慣に組み込まれない
├─ isParallelExecution (boolean)
│  true の場合、複数のタスク・習慣を並行実行している
├─ parallelWith (array of UUID)
│  並行実行中の他のタスク/習慣ID
├─ executedAt (timestamp)
├─ isIncludedInReport (boolean)
│  レポートモードに含めるか（通常は true）
├─ isOnboardingCandidate (boolean)
│  Onboarding モードで「習慣化しますか？」と聞くべきか
│  デフォルト：false（単発タスクだから）
│  ただし、ユーザーが明示的に「習慣化したい」と言った場合は true に変更
└─ createdAt (timestamp)
```

**実行モードでの NLP 判定ロジック**：

```
入力：「ちょうどパッカーズvsベアーズが始まったので、
        今日はそれを見ながら自分の朝食を食べて、
        あとでストレッチをしようと思います」

[NLP 解析]

Step 1: キーワード抽出
  - 「パッカーズvsベアーズが始まった」→ 単発イベント
  - 「朝食を食べて」→ 既知の習慣「朝食」 or 単発タスク
  - 「ストレッチをしよう」→ 既知の習慣「ストレッチ」

Step 2: タスク vs 習慣の判定
  - 「パッカーズvsベアーズ」→ Task（単発、習慣ではない）
  - 「朝食」→ 曖昧。文脈から「今日は特別に見ながら食べる」
              という単発的な要素がある
              → Task として記録しつつ、
                関連習慣「朝食」(Habit) にもリンク
  - 「ストレッチ」→ Habit として記録

Step 3: 並行実行の検出
  「見ながら朝食を食べて」→ パッカーズ観戦 と 朝食 が並行
  
  → Task: パッカーズ観戦
      isParallelExecution = true
      parallelWith = ["朝食"]
  
  → HabitExecution: 朝食
      isParallelExecution = true
      parallelWith = ["パッカーズ観戦"]

Step 4: isOnboardingCandidate の判定
  - パッカーズ観戦：一度限りのイベント
    → isOnboardingCandidate = false
  
  - 朝食：既に習慣として定義されている
    → isOnboardingCandidate = false
  
  - ストレッチ：「あとでストレッチをしよう」は単なる計画
    → 実際に実行されていない
    → isOnboardingCandidate = false（将来の実行を見てから判定）
```

---

### 3.0.2 Onboarding モード

**目的**：習慣の定義と最適化。ユーザーとの対話を通じて、習慣に関する詳細な情報を取得・更新する。

**特徴**：
- タイムシフト可能（リアルタイムではなく、タイミング的に都合が良い時に実行）
- 質問リストキュー（QueuedOnboardingQuestions）を使用
- 生成AI による動的な質問生成も可能
- 習慣の再検討・最適化に専念

### 3.0.2.1 実行モード → Onboarding モード：質問リスト記録（自動遷移ではない）

**変更点：**

実行モードでユーザーが詳細情報を提供した場合、**自動的に Onboarding モードへ遷移しない**。代わりに、その情報を **QueuedOnboardingQuestions にキューとして記録** し、ユーザーが後で手動で Onboarding モードへ移行した時に質問される。

**処理フロー**：

```
【実行モード処理】

ユーザー入力：「はい。ただし正確には、その前に居間の机をどかしていました。
            小さな丸机で、これをどかすことでストレッチをやれる空間を
            つくっているのです。」

[NLP 詳細解析]

新しい習慣候補：「居間の机をどかす」（環境準備習慣）
新しいチェーン関係：朝食 → 机をどかす → ストレッチ

[実行モード応答 - シンプル]

「ご説明ありがとうございます。
 朝食実行済みとして記録します。
 ストレッチについても、朝食後の予定として記録しておきます。」

[バックグラウンド処理 - 質問リスト記録]

QueuedOnboardingQuestions に以下を追加：

{
  "questionId": "uuid-queue-001",
  "source": "execution_mode_detail",
  "priority": "high",
  "addedAt": "2025-01-01 09:45",
  
  "topic": "ストレッチの前提条件習慣",
  
  "habit": {
    "habitId": "move-table-001",
    "habitName": "居間の机をどかす",
    "context": "ユーザーが『その前に居間の机をどかしていました』と報告。
               小さな丸机で、これをどかすことでストレッチができる空間を作っている。"
  },
  
  "questionsToAsk": [
    {
      "order": 1,
      "shortQuestion": "『居間の机をどかす』ことは、毎回必要ですか？",
      "detailedQuestions": [
        "ストレッチの前に毎回机をどかす必要がありますか？",
        "それとも、時によって不要な場合もありますか？"
      ]
    },
    {
      "order": 2,
      "shortQuestion": "机をどかすのに、どのくらい時間がかかりますか？",
      "detailedQuestions": [
        "小さな丸机とのことですが、どのくらいの時間で移動できますか？"
      ]
    },
    {
      "order": 3,
      "shortQuestion": "『居間の机をどかす』を、独立した習慣として扱いますか、それともストレッチの一部として扱いますか？",
      "detailedQuestions": [
        "これを独立した習慣として記録したいですか？",
        "それとも、『ストレッチの準備ステップ』として扱いたいですか？"
      ]
    }
  ]
}

【実行モード終了】

シンプルな応答のみをユーザーに表示。
質問リストはバックグラウンドで記録され、
ユーザーが Onboarding モードへ手動移行した時に表示される。
```

**修正後の AI 応答（実行モード）**：

```
┌──────────────────────────────────────────┐
│  Habit Chat Interface                    │
├──────────────────────────────────────────┤
│                                          │
│  ご説明ありがとうございます。             │
│                                          │
│  朝食実行済みとして記録します。           │
│                                          │
│  ストレッチについても、朝食後の予定と    │
│  して記録しておきます。                  │
│                                          │
│  では、観戦と朝食をお楽しみください。   │
│                                          │
│  ────────────────────────────────────   │
│                                          │
│  💡 Tip: 習慣について詳しく見直したい   │
│     場合は、Settings > 「習慣を見直す」 │
│     をタップしてください。               │
│                                          │
└──────────────────────────────────────────┘
```

**ユーザーが後で Onboarding モードへ手動移行した時：**

```
┌──────────────────────────────────────────┐
│  Habit Chat Interface                    │
│  【Onboarding モード】                   │
├──────────────────────────────────────────┤
│                                          │
│  【新しい習慣について】                  │
│                                          │
│  本日の実行モードでの報告から、           │
│  『居間の机をどかす』という新しい習慣    │
│  が見えてきました。                      │
│                                          │
│  これについて、詳しくお聞きしたいことが │
│  あります。                              │
│                                          │
│  ════════════════════════════════════   │
│                                          │
│  【質問1】                               │
│  『居間の机をどかす』ことは、             │
│  ストレッチの前に毎回必要ですか？        │
│                                          │
│  [ はい、毎回 ]  [ 時によります ]      │
│  [ いいえ、不要 ]                       │
│                                          │
│  ────────────────────────────────────   │
│                                          │
│  【質問2】                               │
│  机をどかすのに、どのくらい時間が        │
│  かかりますか？                          │
│                                          │
│  [ 1～2分 ]  [ 3～5分 ]  [ 5分以上 ]   │
│                                          │
│  ────────────────────────────────────   │
│                                          │
│  【質問3】                               │
│  『居間の机をどかす』を、独立した習慣    │
│  として記録したいですか？                │
│  それとも、『ストレッチ』の一部として    │
│  扱いたいですか？                        │
│                                          │
│  [ 独立した習慣 ]  [ ストレッチの一部 ] │
│                                          │
└──────────────────────────────────────────┘
```

```
1. 自動トリガー（OnboardingUpdateTrigger）
   - 実行モードで無活動が60分以上続いた場合
   - 週1回の定期分析後
   - 月1回の大規模レビュー

2. ユーザー明示的トリガー
   - Settings > 「習慣を見直す」をタップ
   - 「Onboarding を再実施」を選択

3. 実行モードからのキュー
   - 実行モード中に「習慣の詳細化が必要」と判定された場合、
     質問を QueuedOnboardingQuestions に追加
     → 次回の Onboarding 時に表示
```

**【新規追加】QueuedOnboardingQuestions（Onboarding 質問キュー）**

```
QueuedOnboardingQuestions:
├─ id (UUID)
├─ userId (外部キー)
├─ interviewId (外部キー)
│  参照している現在の Interview バージョン
├─ questionsQueue (array of objects)
│  [
│    {
│      "questionId": "uuid-1",
│      "source": "execution_mode" | "auto_trigger" | "user_request",
│      "habit": {
│        "habitId": "stretch-001",
│        "habitName": "ストレッチ（軽く）",
│        "context": "実行モードで『朝食後の1時間後にストレッチをやりたい』
│                   という発言が検出された。
│                   現在の定義では『朝7時起床の直後』となっているため、
│                   チェーン順序を再検討する必要がある。"
│      },
│      "shortQuestion": "ストレッチは実際には『朝食後の1時間後』ですか？",
│      "detailedQuestions": [
│        "なぜ『朝食後の1時間後』なのですか？",
│        "『朝食の直後』ではなく『1時間後』という理由は何ですか？",
│        "毎日1時間後ですか、それとば柔軟ですか？",
│        "その時間に実際にストレッチができる環境ですか？"
│      ],
│      "priority": "high" | "medium" | "low",
│      "addedAt": timestamp,
│      "answeredAt": timestamp (nullable),
│      "userAnswer": text (nullable)
│    },
│    {
│      "questionId": "uuid-2",
│      "source": "auto_trigger",
│      "topic": "朝食の実行パターン分析",
│      "shortQuestion": "朝食は毎日同じ時間ですか、それとも変動していますか？",
│      "priority": "medium",
│      "addedAt": timestamp,
│      ...
│    }
│  ]
├─ totalQuestions (integer)
│  キュー内の全質問数
├─ answeredCount (integer)
│  回答済みの質問数
└─ lastUpdatedAt (timestamp)
```

**Onboarding モードの処理フロー**：

```
[Onboarding モード開始]
  ↓
IF QueuedOnboardingQuestions.questionsQueue に内容がある
  → 優先度順に質問を提示
  → ユーザーが回答
  → InterviewUpdate.userFeedback に記録
  → 習慣設定を更新
  ↓
ELSE IF キューが空
  → AI が自動で質問を生成
    （行動データやパターン分析に基づいて）
  → または「レポートモードを実行して、
    その結果に基づいて質問を生成する」ことを提案
```

---

### 3.0.3 レポートモード

**目的**：習慣の達成状況、進捗、パターンを分析し、ユーザーにフィードバックを提供。モチベーション維持。

**特徴**：
- 重い処理（データ分析、AI による複合分析）を含む
- リアルタイムではなく、定期実行（毎日深夜、週1回など）
- 複数の Task と Habit データを統合分析
- 次の Onboarding モードへの質問を生成

**レポートモードのトリガー**：

```
1. 自動トリガー
   - 毎日深夜1回（その日のサマリーレポート）
   - 週1回（週間分析レポート）
   - 月1回（月間総括レポート）

2. ユーザー明示的トリガー
   - Settings > 「進捗を確認する」をタップ
   - Onboarding モード中に「データ分析レポートを見る」を選択
```

**【新規追加】HabitReport（レポート記録）**

```
HabitReport:
├─ id (UUID)
├─ userId (外部キー)
├─ reportType (enum)
│  "daily" | "weekly" | "monthly"
├─ periodStart (timestamp)
├─ periodEnd (timestamp)
├─ habitAnalysis (JSON object)
│  {
│    "completedHabits": [
│      {
│        "habitId": "朝食",
│        "completionRate": 0.95,
│        "consecutiveDays": 5,
│        "trend": "improving" | "stable" | "declining"
│      }
│    ],
│    "strugglingHabits": [
│      {
│        "habitId": "ストレッチ",
│        "completionRate": 0.20,
│        "reason": "朝の時間がない",
│        "suggestion": "朝から削除を検討、または別の時間帯へ移す"
│      }
│    ]
│  }
├─ taskSummary (JSON object)
│  {
│    "totalTasks": 5,
│    "taskExamples": [
│      "パッカーズ vs ベアーズ観戦",
│      "午前の会議",
│      "子どもの病院予約"
│    ],
│    "note": "これらは単発タスクで、習慣には含まれていません"
│  }
├─ parallelExecutionPatterns (array)
│  [
│    {
│      "combination": ["パッカーズ観戦", "朝食"],
│      "occurrences": 1,
│      "note": "見ながら食事をしている"
│    }
│  ]
├─ generatedInsights (array of strings)
│  AI が生成した洞察・提案
│  [
│    "朝食の習慣は非常に安定しており、習慣づけが成功していると考えられます",
│    "一方、ストレッチは実行率が低く、現在の『朝7時直後』という定義が
│      現実的ではないと思われます",
│    "『朝食後の1時間後』という実際のパターンに合わせた方が、
│      習慣化が進むかもしれません"
│  ]
├─ nextOnboardingQuestions (array of UUID)
│  このレポートから提案された Onboarding 質問の ID
│  （QueuedOnboardingQuestions へ自動追加）
├─ motivationalMessage (string)
│  ユーザーへのポジティブなフィードバック
│  「先週は朝食の習慣が100%達成されました。素晴らしい！」
├─ generatedAt (timestamp)
└─ isShownToUser (boolean)
   ユーザーに表示済みか
```

---

### 3.0.4 モード間のデータフロー

```
【実行モード】
  ↓
ユーザー報告 → Message 記録
  ↓
NLP: タスク vs 習慣判定
  ↓
Habit OR Task として記録
  ↓
ExecutionInference 生成（習慣の場合）
  ↓
チェーン整合性チェック
  ↓
必要なら QueuedOnboardingQuestions にキュー追加
  ↓
シンプルな AI 応答
  ↓
─────────────────────────────────────
  ↓
【Onboarding モード】（自動トリガーまたはユーザー明示的）
  ↓
QueuedOnboardingQuestions から質問を提示
  ↓
ユーザーが回答
  ↓
InterviewUpdate 生成・習慣設定更新
  ↓
─────────────────────────────────────
  ↓
【レポートモード】（定期実行）
  ↓
Habit + Task + ExecutionInference を統合分析
  ↓
HabitReport 生成
  ↓
次の Onboarding 質問を QueuedOnboardingQuestions へ追加
  ↓
ユーザーへのレポート表示（UIで）
```

### 3.0.5 OnboardingUpdateTrigger（Onboarding更新の自動トリガー）

```
OnboardingUpdateTrigger:
├─ id (UUID)
├─ userId (外部キー)
├─ currentInterviewVersion (integer)
├─ lastActivityTime (timestamp)
│  ユーザーの最後のメッセージ・報告タイムスタンプ
├─ inactivityThresholdMinutes (integer, default=60)
│  この時間以上、ユーザーからの新規報告がない場合、
│  Onboarding更新を検討
├─ shouldTriggerUpdate (boolean)
│  更新をトリガーするべきか、の判定フラグ
│  計算ロジック：
│    現在時刻 - lastActivityTime > inactivityThresholdMinutes
│    AND
│    今日のメッセージ数 >= 3（最小限の活動実績がある）
│    AND
│    前回のOnboarding更新から > 6時間（更新の頻度制限）
├─ suggestedUpdateType (enum)
│  "micro" | "weekly" | "review"
│  micro: 日中の小さな調整（1～2つの習慣）
│  weekly: 週1回の詳細分析（複数習慣の評価）
│  review: 月単位の大規模更新（パターン再発見）
├─ proposedQuestions (array of objects)
│  [
│    {
│      "priority": 1,
│      "question": "土曜日は『朝7時起床』ではなく『9時30分起床』なのですね。
│                   毎週末、起床時刻は遅めなのでしょうか？
│                   それとも、今日たまたま遅くなったのでしょうか？",
│      "relatedHabit": "朝7時起床",
│      "context": "昨日は『朝7時起床』の定義だが、
│                 今日は9時30分に起床という矛盾"
│    },
│    {
│      "priority": 2,
│      "question": "土曜日の朝のルーティンについて、
│                   平日と同じ流れをやりたいのか、
│                   それとも別の流れがあるのか、教えていただけますか？",
│      "relatedHabit": ["朝食", "ストレッチ", "子ども朝ごはん準備"],
│      "context": "平日と土曜日の朝ルーティンの定義が不明確"
│    }
│  ]
├─ triggeredAt (timestamp, nullable)
│  実際に更新がトリガーされた日時
└─ userResponded (boolean, default=false)
   ユーザーが提案された質問に回答したか
```

---

### 3.1 初期 Onboarding フロー（改良版：理想を一度に、現実で継続調整）

**設計思想：**
初期Onboarding では、ユーザーの「理想とする生活」をすべて一度に取り込む。その後、実際の利用データに基づいて、**頻繁かつ継続的に習慣を再定義・調整していく**。AIは「理想と現実のギャップ」を認識し、ユーザーと一緒に現実的な習慣へと柔軟に修正していく。

```
[アプリ初回起動]
  ↓
[AI: 本格的なインタビュー]
「あなたの理想的な生活について、
 朝から夜まで、すべて教えてください。」
  ↓
User Input（複数回のやり取り）
  ↓
[NLP: 包括的な抽出]
  - すべての mentionedHabits を抽出
  - すべての triggers を抽出
  - すべての dependencies を抽出
  - チェーン関係を完全に把握
  ↓
[AI: 完全な提案]
「では、あなたの理想的なルーティンを定義します：
 
 【朝のルーティン】
 - 朝7時起床
 - 洗顔・身だしなみ
 - コーヒーボタンON
 - ストレッチ（軽く）
 - 子どもの朝ごはん準備
 ...
 
 【夜のルーティン】
 - 夜23時就寝（基本）
 - 週1回、分割睡眠でアイドル配信視聴
 ...
 
 以上で大丈夫ですか？」
  ↓
User Confirmation
  ↓
[すべての Habit を一度に DB に保存]
[すべての HabitChain を一度に DB に保存]
[Interview.completionPercentage = 100（理想状態として）]
[Interview.readyForUsage = true]
  ↓
[AI: ユーザーへの重要な説明]
「では、これからこの理想的なルーティンを
 一緒に実現していきましょう。
 
 ただし、最初はすべてを完璧にはできないかもしれません。
 実際に試してみて、うまくいかないことがあれば、
 一緒に工夫して、あなたに合った形に調整していきます。
 
 毎日、実行結果を教えてくださいね。」
  ↓
[メイン画面へ遷移 - アプリ利用開始]
```

**利用開始後：継続的なOnboarding更新フロー**

```
[Day 1 - 3日目まで（試行期間）]
- ユーザーが定義された習慣について報告
- AI が推測判定とフィードバック促進
- ExecutionInference で学習開始

[3日目の夜 or Day 4（初回微調整）]
→ 初期データ（3日間）を分析
→ AI: 「朝7時起床は2日成功されましたね。素晴らしい。
         ただ『ストレッチ』は実行されていないようです。
         朝の時間が実は少ないのでしょうか？
         それとも、ストレッチのタイミングや内容を変えた方がいいですか？」
→ ユーザーと一緒に習慣の調整案を検討
→ 必要に応じて HabitChain の delayMinutes を変更、
  Habit の description を修正、などを実施

[Weekly（週1回）- より詳細な分析】
→ 過去7日間の完了率を分析
→ 完了率の高い習慣：「朝7時起床（100%）」「朝食（95%）」
→ 完了率の低い習慣：「ストレッチ（20%）」「朝勉強（0%）」
→ AI: 「朝のルーティンでは『朝7時起床』『朝食』は習慣づけられました。
        一方『ストレッチ』と『朝勉強』は難しいようです。
        これらについて、どうしましょうか？
        A案: 一旦保留して、別の時間帯でやる
        B案: 内容や時間を変える
        C案: あきらめる」

[Bi-weekly（隔週）- より大規模な更新]
→ 実行パターンの自動分析
→ 予期しない新しい習慣の発見
→ 習慣づけ完了の宣言
→ Interview を新バージョンに更新
```

### 3.2 日常利用フロー（実行報告 + 自動Onboarding更新トリガー統合版）

```
[ユーザーがメッセージ入力]
例: 「コーヒーメーカーを動かし、子どもに朝食を出しました」
  ↓
[Message を DB に保存]
  ↓
[NLP: 入力テキストを解析]
  - 関連Habitを特定
  - 関連Chainを特定
  ↓
[AI: Habit実行の推測判定]
  - ExecutionInference を生成
  - executionType (direct/partial/inferred) を決定
  - completionPercentage を決定
  ↓
[HabitExecution を生成]
  ↓
[HabitChain をチェック]
  - nextHabit が存在するか？
  - triggerCondition は満たされたか？
  ↓
[AI: ユーザーへの応答メッセージを生成]
  ↓
[OnboardingUpdateTrigger を更新]
  - lastActivityTime = 現在時刻
  - inactivityThreshold = 60分（デフォルト）
  - shouldTriggerUpdate を判定
  ↓
【重要】inactivityThreshold を超えた時点での処理：
  ↓
IF （現在時刻 - lastActivityTime >= 60分）
   AND （今日のメッセージ数 >= 3）
   AND （前回のOnboarding更新から >= 6時間）
THEN
  → OnboardingUpdateTrigger.shouldTriggerUpdate = true
  → proposedQuestions を AI が生成
  → ユーザーに対話的に提案
  → Interview.sessionType = "incremental" で新バージョン作成
  ↓
[optional] ユーザーが ExecutionInference に対してフィードバック
  - 「その判定は正しい」
  - 「いや、実は△△だった」
  ↓
[AILearning: フィードバックを学習、次回の推測精度向上]
```

**具体例：本デモの場合**

```
09:30 - ユーザー入力1: 「9:30に起きました」
        → Message 保存
        → ExecutionInference: 「朝7時起床」の定義と矛盾を検出
        → lastActivityTime = 09:30
        → メッセージ数: 1
        ↓
09:35 - ユーザー入力2: 「コーヒーメーカーを動かし、子どもに朝食を出しました」
        → Message 保存
        → ExecutionInference: 「コーヒーボタンON」「子ども朝ごはん準備」 を検出
        → lastActivityTime = 09:35
        → メッセージ数: 2
        ↓
09:40 - AI応答生成
        「コーヒーとお子さんの朝食を準備されたんですね。
         素晴らしい。」
        ↓
10:35 - 1時間経過（最後のユーザー報告から）
        → OnboardingUpdateTrigger が自動評価
        → shouldTriggerUpdate = true となる条件を確認
           ✓ 60分以上の無活動
           ✗ メッセージ数 2（< 3 なので、まだ足りない可能性）
           
        判定：「朝の段階が一応完了したと見なせるか」
        → AI判定：朝の主要報告（起床、朝食）が済んだので、
                  この段階で「朝の習慣について質問するタイミング」と判定
        ↓
AI から Akira へ通知：
「朝のルーティンが一段落したようですね。
 ところで、質問させていただけますか？

 土曜日は『朝7時起床』ではなく『9時30分起床』なのですね。
 毎週末、起床時刻は遅めなのでしょうか？
 それとも、今日たまたま遅くなったのでしょうか？
 
 教えていただけると、習慣を改善できます。」

        ↓
ユーザーが回答
「土曜日は起床が遅めになります。子どもの送迎がないので。」
        ↓
Interview.versionNumber を更新（v1 → v2）
- 「朝7時起床」を「平日は朝7時起床、土曜日は遅め」に修正
- 土曜日の定義を追加
- HabitChain を平日用・土曜用で分岐
```

**Interview データモデルでの実装：**

```
初回起動（Onboarding完了）:
Interview {
  id: "interview-001",
  versionNumber: 1,
  sessionType: "initial",
  generatedHabits: [
    "朝7時起床",
    "洗顔・身だしなみ",
    "コーヒーボタンON",
    "ストレッチ（軽く）",
    "子どもの朝ごはん準備",
    "登園送迎",
    "朝の自分の朝食",
    "仕事開始（9時30分）",
    "夜23時就寝（基本）",
    "アイドル配信視聴（週1回）"
  ],
  generatedChains: [
    "朝7時起床 → 洗顔 (0分)",
    "洗顔 → コーヒーボタンON (5分)",
    "コーヒーボタンON → ストレッチ (5分)",
    "ストレッチ → 子どもの朝ごはん準備 (5分)",
    ...
  ],
  completionPercentage: 100,  // 理想状態として
  readyForUsage: true,
  plannedFollowUp: "2025-01-03" (3日後の初回微調整)
}

Day 4（初回微調整）:
Interview {
  id: "interview-002",
  versionNumber: 2,
  sessionType: "incremental",
  changes: [
    {
      "habitId": "stretch-001",
      "changeType": "modified",
      "originalDescription": "ストレッチ（軽く、5分）",
      "modifiedDescription": "ストレッチ（軽く、3分）or パスOK",
      "reason": "実行率が低かったため、難度を下げた"
    }
  ],
  completionPercentage: 95,
  plannedFollowUp: "2025-01-10" (週1回分析)
}

Day 10（Weekly分析）:
Interview {
  id: "interview-003",
  versionNumber: 3,
  sessionType: "review",
  analysis: {
    "completedHabits": ["朝7時起床", "朝食", "登園送迎"],
    "strugglingHabits": ["ストレッチ", "朝勉強"],
    "suggestedChanges": [...]
  },
  completionPercentage: 85,
  plannedFollowUp: "2025-01-17" (次の週1回分析)
}
```

**頻繁な更新のスケジュール案：**

```
初回Onboarding完了 → Day 1-3
  ↓
初回マイクロ調整 → Day 3-4（少なくとも1つの習慣調整）
  ↓
Weekly深掘り分析 → Day 7（完了率分析、困難習慣の検討）
  ↓
Bi-weekly大規模更新 → Day 14（パターン発見、新習慣追加/削除の検討）
  ↓
Monthly全体振り返り → Day 30（1ヶ月のデータ総合分析）
```

**AI が提案する習慣再定義の例：**

```
【Day 4 - 初回マイクロ調整】
User Input: 「朝は時間が思ったより短いです。」

AI: 「なるほど。では、朝のルーティンを見直しましょう。
    現在、起床から登園出発までが約60分ですが、
    
    実際には：
    - 洗顔・身だしなみ: 10分
    - 子どもの朝ごはん準備・食べさせ: 20分
    - 登園準備: 15分
    
    で、約45分しか使えていないんですね。
    
    そうすると、『ストレッチ』『朝勉強』の時間がない。
    
    こういう方法はいかがでしょう：
    
    案1: ストレッチを朝ではなく、夜に移す
    案2: ストレッチを『できたらでいい』くらいに変える
    案3: 朝の時間を捻出する工夫（何か削れることがあるか）
    
    どれがいいですか？」
```

```
【Day 10 - Weekly深掘り分析】
AI: 「朝7時起床の習慣は100%達成されていて、素晴らしい。
    『朝食』『登園送迎』も安定していますね。
    
    一方、『ストレッチ』は実行率20%のままです。
    『朝勉強』は0%です。
    
    正直なところ、この2つは現在のあなたの生活では
    難しいのではないでしょうか？
    
    【提案】
    - 『ストレッチ』『朝勉強』を一旦、
      『朝の習慣』のリストから削除する
    - かわりに、『仕事開始前の準備』や
      『子どもとの朝の時間』を明示的に定義する
    - 『ストレッチ』『勉強』については、
      別の時間帯（例えば仕事の合間、夜）で
      機会があれば取り組む、くらいの位置付けにする
    
    いかがでしょう？」
```

### 3.2 日常利用フロー（実行報告）

```
[ユーザーがメッセージ入力]
例: 「ウォーミングアップをやった」
  ↓
[Message を DB に保存]
  ↓
[NLP: 入力テキストを解析]
  - 関連Habitを特定
  - 関連Chainを特定
  ↓
[AI: Habit実行の推測判定]
  - ExecutionInference を生成
  - executionType (direct/partial/inferred) を決定
  - completionPercentage を決定
  ↓
[HabitExecution を生成]
  ↓
[HabitChain をチェック]
  - nextHabit が存在するか？
  - triggerCondition は満たされたか？
  - delayMinutes 後に提案するか、即座に提案するか？
  ↓
[AI: ユーザーへの応答メッセージを生成]
  ↓
[optional] ユーザーが ExecutionInference に対してフィードバック
  - 「その判定は正しい」
  - 「いや、実は△△だった」
  ↓
[AILearning: フィードバックを学習、次回の推測精度向上]
```

### 3.3 フィードバック・ループ

```
[AI の推測が表示される]
  ↓
ユーザーが確認
  ↓
正しい場合：
  → ExecutionInference.userFeedback.isCorrect = true
  → aiLearningApplied に記録
  ↓
不正確な場合：
  → ExecutionInference.userFeedback.isCorrect = false
  → ExecutionInference.userFeedback.correctedInference で修正内容を入力
  → AIがその修正パターンを学習
  → 類似状況で次回は改善された推測をする
```

### 3.4 Onboarding 更新フロー

```
[バックグラウンド定期処理（例：週1回）]
  ↓
[実行データを分析]
  - 過去N日間の HabitExecution を統計分析
  - 完了率が高い習慣 → 習慣づけ完了と判定
  - 完了率が低い習慣 → アーカイブ候補と判定
  - 新しいパターンを発見 → 新規Chain候補と判定
  ↓
[InterviewUpdate を生成]
  - proposedChanges を AI が提案
  - questionsForUser を AI が生成
  ↓
[ユーザーへの提案メッセージ]
例: 「当初のOnboardingでは『朝食』『昼食』『夕食』タスクを定義していましたが、
     過去2週間の実行ログを見ると、『朝食』は11日中10日完了（91%）で、
     もう習慣づけられているようです。
     一方、『ピアノの練習』は9日中6日完了（67%）で、
     さらにサポートが必要なようです。
     また、『夜の読書』という習慣があることを観察しました（過去5回）。
     これについて、追加でご情報ですか？」
  ↓
ユーザーが回答
  ↓
InterviewUpdate.userApprovalStatus = "approved" / "rejected" / "partially_approved"
  ↓
承認されたら、新しい Interview バージョンを作成
  Interview.versionNumber をインクリメント
  変更を HabitExecution, HabitChain に反映
  ↓
[Onboarding Update 完了]
```

---

## 4. AI推測ロジックの詳細

### 4.1 ExecutionType 判定アルゴリズム

ユーザー入力「ウォーミングアップをやった」の場合：

```
1. 入力の NLP 解析
   → "ウォーミングアップ" というキーワードを抽出

2. 関連習慣の検索
   → DB から "ウォーミングアップ" に該当する HabitStep を検索
   → その親 Habit 「ピアノの練習」を特定

3. 文脈的判定（ExecutionType 決定）
   
   IF 「ウォーミングアップ」が「ピアノの練習」の直接の子習慣か？
      ↓ YES
      
      IF 「ウォーミングアップ」のみで「ピアノの練習」が完全完了と判定されるべきか？
         (Habit.completionLogic で制御)
         ↓ YES (completionLogic.type = "any_step" の場合)
         
         ExecutionType = "direct"
         CompletionPercentage = 100
         
         ↓ NO (completionLogic.type = "all_steps" の場合)
         
         他のステップも必要と判定
         ExecutionType = "inferred"
         CompletionPercentage = (1 / totalSteps) * 100
         例: 3ステップ中1番目 → 33%
      
      ↓ NO
      
      IF 過去のログから「ウォーミングアップ」と「ピアノの練習」の関連が強いか？
         (ExecutionInference の userFeedback 履歴で学習)
         AND 確信度 > 0.7？
         
         ↓ YES
         
         ExecutionType = "inferred"
         CompletionPercentage = (学習した関連度に基づく)
         
         ↓ NO
         
         ExecutionType = "partial"
         CompletionPercentage = 低め（例：20%）
         または習慣との関連が不明確と判定

4. CompletionPercentage の詳細計算
   
   IF ExecutionType = "direct"
      CompletionPercentage = 100
   
   ELSE IF ExecutionType = "inferred"
      CompletionPercentage = (
        completedStepsCount / totalStepsCount * 100
      ) + (
        // AI学習から得た確信度ボーナス
        (confidence - 0.5) * 20
      )
      
   ELSE IF ExecutionType = "partial"
      CompletionPercentage = (
        estimatedStepValue + contextBonus
      )
      
      contextBonus は、例えば：
      - 「ウォーミングアップ」は通常1番目のステップ → +10%
      - 1日の中で最初の言及 → +5%
      
5. ユーザーへの提案文生成
   
   IF CompletionPercentage = 100
      "『ウォーミングアップ』完了ですね。ピアノの練習は完了しました。
       素晴らしい！連続 N 日達成です。"
   
   ELSE IF CompletionPercentage >= 50
      "『ウォーミングアップ』完了ですね。ピアノの練習は X% 進みました。
       次は『スケール練習』をされますか？"
   
   ELSE
      "『ウォーミングアップ』をやられたんですね。
       良いスタートです。実際には他にどんなことを？"
```

### 4.2 デバッグモード（debugInfo）

`Settings > Debug Mode = ON` の場合、AI応答に以下を追加：

```
[Debug Information]

推測結果:
- 習慣: ピアノの練習
- タイプ: inferred
- 完了度: 33%

推測根拠:
- 確信度: 0.75（中程度）
- 判定理由: 
  * Onboarding時に「ウォーミングアップ」が
    「ピアノの練習」の3ステップ中1番目と記録
  * completionLogic = "all_steps" であり、
    全ステップ完了で初めて完全完了
  * したがって、1ステップ = 約33%進捗

類似過去事例:
- 同じ「ウォーミングアップ」→「ピアノの練習」の推測は
  過去7回実行、うち確認済みフィードバック5回正解、2回修正
  → 正解率71%

代替推測:
- もし「ウォーミングアップ」のみで十分と考える場合:
  → ExecutionType = "direct", CompletionPercentage = 100

学習状況:
- 過去2週間でこのパターンの信頼度が 0.68 → 0.75 に上昇
- ユーザーフィードバック: 最後の修正は4日前
```

---

## 5. UI/UX の基本的な方針

### 5.1 メイン画面（日常利用時 - シンプル版）

```
┌──────────────────────────────────┐
│  Habit Chat Interface            │
├──────────────────────────────────┤
│                                  │
│  【メッセージ】                  │
│  コーヒーとお子さんの朝食を      │
│  準備されたんですね。            │
│  素晴らしい。                    │
│                                  │
│  ────────────────────────────   │
│                                  │
│  【確認質問】（シンプル）        │
│  洗顔はしましたか？              │
│  またストレッチはしましたか？    │
│                                  │
│  [ はい / いいえ / 説明する ]    │
│                                  │
└──────────────────────────────────┘
```

---

### 5.2 Onboarding フェーズ画面（詳細質問版）

Onboarding が自動トリガーされた場合、または ユーザーが「Onboarding を再実施」を選択した場合：

```
┌──────────────────────────────────────┐
│  Onboarding - 習慣の詳細検討        │
├──────────────────────────────────────┤
│                                      │
│  【朝のルーティン見直し】            │
│                                      │
│  本日、いくつかの習慣について        │
│  確認させていただきたいことがあります│
│                                      │
│  ════════════════════════════════   │
│                                      │
│  【習慣1：洗顔・身だしなみ】        │
│                                      │
│  今朝は洗顔をされませんでしたね。   │
│                                      │
│  理由を教えていただけますか：        │
│  1. 朝の時間が足りなかった          │
│  2. 習慣として定着していない        │
│  3. その他                          │
│                                      │
│  [ 選択または自由記述 ]              │
│                                      │
│  ────────────────────────────────   │
│                                      │
│  今後、洗顔は朝のルーティンに        │
│  含めたいですか？                   │
│                                      │
│  [ はい / いいえ / 工夫したい ]     │
│                                      │
│  ════════════════════════════════   │
│                                      │
│  【習慣2：ストレッチ（軽く）】      │
│                                      │
│  ストレッチもされていないようですね。│
│  朝のルーティンから削除を検討しても│
│  いいと思いますが、いかがですか？   │
│                                      │
│  [ 続けたい / 削除したい /         │
│    別の時間帯でやりたい ]           │
│                                      │
└──────────────────────────────────────┘
```

### 5.2 Onboarding インタビュー画面

```
┌─────────────────────────────────┐
│  Onboarding Interview Session   │
├─────────────────────────────────┤
│                                 │
│  進捗: ████░░░░░░ 40%            │
│                                 │
│  AI質問:                         │
│  「朝6時に起床する習慣について、 │
│   その後、最初にすることは？」   │
│                                 │
│  [これまでの回答サマリー]       │
│  ✓ 起床時刻: 朝6時              │
│  ✓ 家族構成: 5歳の男児がいる    │
│  • 職業: ITエンジニア           │
│                                 │
│  [ユーザー入力]                 │
│  コーヒーを飲みます。子どもも    │
│  一緒に朝ごはんを食べます。      │
│                                 │
│  [AI抽出結果の確認]             │
│  抽出された習慣:                 │
│  □ 起床 (6時)                   │
│  □ コーヒーを飲む (直後)        │
│  □ 朝食 (起床後)                │
│                                 │
│  これで大丈夫ですか？           │
│  [修正] [確定して続ける]         │
│                                 │
└─────────────────────────────────┘
```

### 5.3 Habit チェーン可視化

```
朝のルーティン:
  [起床] ─(0分)─> [コーヒー] ─(5分)─> [朝食] ─(10分)─> [子ども送り]
   ●(12日)        ●(12日)         ●(12日)        ▲(8日)

夜のルーティン:
  [子ども就寝] ─(15分)─> [ピアノ準備] ─(0分)─> [ピアノ練習]
   ●(28日)              ▲(18日)              ▲(12日)
                            │
                            └─> [ウォーミングアップ] ─(5分)─> [スケール]
                                 ▲(12日)                    ▲(8日)
                                                               │
                                                               └─> [好きな曲]
                                                                   ▲(5日)

凡例:
● = 習慣づけ完了（信頼度高）
▲ = 習慣化中（まだサポート必要）
─ = チェーン（トリガー関係）
(N日) = 連続実行日数
```

### 5.4 設定画面

```
┌─────────────────────────────────┐
│  Settings                       │
├─────────────────────────────────┤
│                                 │
│ [Onboarding]                    │
│ ├─ Onboarding を再実施          │
│ ├─ 最新の提案を確認             │
│ └─ Onboarding 履歴 (Ver. 1-3)   │
│                                 │
│ [デバッグ]                      │
│ ├─ Debug Mode: [ON/OFF]         │
│ └─ AI 推測の詳細表示: [ON/OFF]  │
│                                 │
│ [データ管理]                    │
│ ├─ 実行ログをエクスポート       │
│ ├─ 習慣の統計情報               │
│ └─ チェーン学習状況             │
│                                 │
│ [フィードバック]                │
│ ├─ 未確認のAI推測 (3件)         │
│ └─ 過去のフィードバック履歴     │
│                                 │
└─────────────────────────────────┘
```

---

## 6. 技術的な実装上の考慮事項

### 6.1 生成AI の統合

**使用予定の LLM:** Claude API (Sonnet 4.5 推奨)

**プロンプト設計：**
- システムプロンプト：「あなたはユーザーの秘書です。習慣形成をサポートします」
- コンテキスト：前回の Onboarding の内容、今回の入力、関連する過去の実行ログ
- 出力形式：JSON で、推測結果、提案、次の質問を構造化

### 6.2 NLP 処理

- **入力解析：** ユーザーの自由記述から Habit, Temporal Info, Trigger を抽出
  - 既知の習慣名との fuzzy match
  - 時間表現の自然言語解析（「朝6時」→ 6:00, 「今」→ current time）
  
- **出力生成：** AI が自然な日本語で提案・質問を生成
  - 毎回表現を変える（テンプレート化を避ける）
  - 前の会話の文脈を反映

### 6.3 学習メカニズム

- **フィードバック学習：** ExecutionInference.userFeedback を蓄積
  - 同じパターンに対する正誤率を計算
  - 確信度（confidence）をアップデート
  - 次回の推測精度を向上

- **パターン自動発見：** HabitChain の自動生成
  - 過去 N日のログから時系列パターンを分析
  - 特定の習慣の後に常に別の習慣がある場合、新しい Chain を提案

---

## 7. Onboarding 更新の詳細フロー

### 7.1 自動分析ロジック

```
[定期実行：例えば毎週日曜深夜]

対象期間：過去14日間の HabitExecution

各 Habit について:
  - 実行回数
  - 完了率（targetFrequency に対する達成度）
  - 連続実行日数（daysChain）
  - ユーザーフィードバック率（ExecutionInference で確認されたか）
  
分類:
  1. 習慣づけ完了（完了率 > 85% かつ 連続7日以上）
     → proposedChanges.archivedHabits に追加
     
  2. 習慣化中（完了率 40-85%）
     → 継続サポートが必要
     
  3. 習慣化失敗（完了率 < 40% かつ連続3日以下）
     → proposedChanges.questionsForUser に「この習慣はまだ続けたいですか？」
  
新パターン発見:
  - 未定義だが、過去14日で5回以上発生した新しいアクション
  - 例：「読書をやった」が5回
  - → proposedChanges.newObservedPatterns に追加
     「『読書』という習慣が観察されました」

関連チェーン発見:
  - 2つの習慣が常に連続実行される（確率 > 90%）
  - 例：「皿を片付ける」が「朝食」「昼食」「夕食」の後に常に実行
  - → proposedChanges の suggestedChain に追加

質問生成:
  - 自動で発見した新パターンについて、ユーザーに確認
  - 例：「『皿を片付ける』習慣は『朝食』『昼食』『夕食』
         すべての後にやるのか、それとも特定の食事の後だけか？」
```

### 7.2 InterviewUpdate → ユーザー提示

```
AI が生成するメッセージ例:

「2週間のデータを分析した結果、いくつかの変化が見えてきました。

【習慣づけ完了】
『朝食』習慣は14日中13日実行（93%）で、
もう習慣づけられているようです。

『皿を片付ける』習慣も同じく14日中12日実行（86%）で、
安定していますね。

【習慣化中 - さらにサポート必要】
『ピアノの練習』は14日中9日実行（64%）です。
もっとサポートが必要なようです。

【新しく観察された習慣】
過去2週間で『夜の読書』を5回実行されていることに気づきました。
これは定義されていない習慣です。
『夜の読書』も習慣化したいですか？

【新しいチェーン関係】
『朝食』『昼食』『夕食』のすべての後に『皿を片付ける』をされています。
ここまで確実に実行されているのは素晴らしいです。

【確認が必要な点】
『皿を片付ける』は『朝食』『昼食』『夕食』のいずれの後でもするのか、
それとも、例えば『夕食』の後だけするのか、教えてもらえますか？

以上を踏まえて、Onboarding を更新してもいいですか？
また、追加でご情報がありましたら、教えてください。」

↓ ユーザー回答

「『夜の読書』は習慣化したいです。
『皿を片付ける』は朝食と夕食の後だけです。昼食後はやっていません。」

↓ AI

「了解です。更新内容を確認します：

【追加】
- 習慣『夜の読書』を追加
  トリガー：『夕食後』
  スケジュール：毎日

【修正】
- 『皿を片付ける』のトリガーを修正
  修正前：『朝食』『昼食』『夕食』の後
  修正後：『朝食』『夕食』の後

【アーカイブ提案】
- 『朝食』を明示的な習慣としてはアーカイブ
  （既に習慣づけられたため）

これでいいですね？」

↓ ユーザー

「はい、その通りです」

↓ AI

「Onboarding を v2 に更新しました。
これからもお手伝いします。」
```

---

## 8. まとめ：アプリの全体像

```
┌─────────────────────────────────────────────┐
│  秘書型習慣形成 AI アシスタント             │
│                                             │
│  初期段階:                                  │
│  ├─ Onboarding で習慣とチェーンを定義     │
│  └─ フィードバックループで AI を育成      │
│                                             │
│  日常利用:                                  │
│  ├─ ユーザーが行動を自由記述               │
│  ├─ AI が文脈を理解して推測判定           │
│  ├─ 次のアクションを提案                   │
│  └─ ユーザーフィードバックで精度向上      │
│                                             │
│  定期更新:                                  │
│  ├─ 実行データを自動分析                   │
│  ├─ 習慣づけ完了を認識                     │
│  ├─ 新しいパターンを発見                   │
│  └─ Onboarding を継続的に更新             │
│                                             │
│  可視化:                                    │
│  ├─ ハビット・チェーン表示                 │
│  ├─ 連続実行日数表示                       │
│  └─ 習慣間の関係図表示                     │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 付録 A：デモで使用する想定シナリオ

### A.1 デモユーザー：Akira（あなた）

基本情報：
- 36歳、日本人男性
- ITエンジニア（リモートワーク、9時30分開始）
- 5歳の男児（息子）がいる
- 身長180cm、体重73kg
- 興味：ピアノ、プロレス（TJPW）、アメリカンフットボール（パッカーズ）、ギター、ウクレレ、アイドル配信

### A.2 初期 Onboarding 完了内容（Interview v1）

**【朝のルーティン - 平日】**

Habit 1: 朝7時起床
- TargetFrequency: daily
- Description: 平日、7時～7時15分に起床する
- IsMinimalStep: true

Habit 2: 洗顔・身だしなみ
- Description: 顔を洗う、歯を磨く、身支度
- EstimatedTimeMinutes: 10
- ParentHabitId: null

Habit 3: コーヒーボタンON
- Description: 前夜に準備してあるコーヒーメーカーのボタンを押す
- EstimatedTimeMinutes: 2
- IsMinimalStep: true

Habit 4: ストレッチ（軽く）
- Description: 軽いストレッチ、可能であれば実施
- EstimatedTimeMinutes: 5
- Difficulty: 0.3

Habit 5: 子どもの朝ごはん準備
- Description: 子どもの朝食を準備し、一緒に食べさせる
- EstimatedTimeMinutes: 20
- ParentHabitId: null

Habit 6: 登園準備・送迎
- Description: 子どもの身支度をして、8時15分～8時45分に登園に送迎
- EstimatedTimeMinutes: 30
- ParentHabitId: null

Habit 7: 自分の朝食
- Description: 登園送迎後、自分の朝食を準備・摂取
- EstimatedTimeMinutes: 15
- ParentHabitId: null

Habit 8: 仕事開始（9時30分）
- Description: リモートワークの業務開始
- TargetFrequency: weekdays
- ParentHabitId: null

**【朝のチェーン関係】**

HabitChain 1: 朝7時起床 → 洗顔・身だしなみ
- DelayMinutes: 0
- TriggerCondition: timeAfter (0分)

HabitChain 2: 洗顔・身だしなみ → コーヒーボタンON
- DelayMinutes: 5
- TriggerCondition: timeAfter (5分)

HabitChain 3: コーヒーボタンON → ストレッチ（軽く）
- DelayMinutes: 5
- TriggerCondition: timeAfter (5分)

HabitChain 4: ストレッチ → 子どもの朝ごはん準備
- DelayMinutes: 5
- TriggerCondition: timeAfter (5分)

HabitChain 5: 子どもの朝ごはん準備 → 登園準備・送迎
- DelayMinutes: 10
- TriggerCondition: timeAfter (10分)

HabitChain 6: 登園送迎 → 自分の朝食
- DelayMinutes: 5
- TriggerCondition: timeAfter (5分)

HabitChain 7: 自分の朝食 → 仕事開始（9時30分）
- DelayMinutes: 30（目安。実際は9時30分を絶対として）
- TriggerCondition: timeAfter (時刻ベース：9時30分)

---

**【夜のルーティン - 基本（週6日）】**

Habit 9: 子どもを寝かしつける
- Description: 22時頃に子どもを寝かしつける
- EstimatedTimeMinutes: 30
- TargetFrequency: daily

Habit 10: 夜23時就寝（基本）
- Description: 23時に就寝する（基本的なリズム）
- TargetFrequency: weekdays_6days（週6日。週1日は配信ある日）
- IsMinimalStep: true

Habit 11: 朝7時起床（結果）
- Description: [注：朝7時起床 と同じもの。夜のチェーンの結果として認識]
- ParentHabitId: "朝7時起床"

**【週1回のアイドル配信習慣】**

Habit 12: アイドル配信視聴（週1回）
- Description: 毎日開催されるアイドル配信のうち、週1回程度視聴する
- TargetFrequency: weekly_1time
- ParentHabitId: null

Habit 13: 分割睡眠（配信ある日）
- Description: 23時就寝 → 25時起床 → 配信視聴（26時～27時半頃） → 28時に再就寝
- TargetFrequency: weekly_1time
- IsMinimalStep: true （分割睡眠を実施する日の初期アクション）

**【夜のチェーン関係】**

HabitChain 8: 子どもを寝かしつける → 夜23時就寝（基本）
- DelayMinutes: 30
- TriggerCondition: timeAfter (30分)

HabitChain 9: 夜23時就寝（基本） → 朝7時起床（結果）
- DelayMinutes: 480（8時間睡眠）
- TriggerCondition: timeAfter (8時間)

HabitChain 10: 配信ある日は、分割睡眠へ
- TriggerCondition: custom (週1回の配信実施予定日)
- NextHabit: "分割睡眠（配信ある日）"

HabitChain 11: 分割睡眠：23時就寝
- DelayMinutes: 0
- TriggerCondition: timeAfter (0)

HabitChain 12: 分割睡眠：25時起床
- DelayMinutes: 120（2時間）
- TriggerCondition: timeAfter (2時間)

HabitChain 13: 分割睡眠：配信視聴（26時スタート）
- DelayMinutes: 60（25時起床から26時まで約1時間）
- TriggerCondition: timeAfter (1時間)

HabitChain 14: 配信終了（27時～28時）→ 再就寝
- DelayMinutes: 0～30
- TriggerCondition: custom (配信終了後すぐ)

---

**【Interview v1 の最終情報】**

```
Interview {
  id: "interview-akira-001",
  userId: "akira-user-001",
  versionNumber: 1,
  sessionType: "initial",
  
  generatedHabits: [
    朝7時起床, 洗顔・身だしなみ, コーヒーボタンON, 
    ストレッチ（軽く）, 子どもの朝ごはん準備, 登園準備・送迎,
    自分の朝食, 仕事開始（9時30分）,
    子どもを寝かしつける, 夜23時就寝（基本）,
    アイドル配信視聴（週1回）, 分割睡眠（配信ある日）
  ],
  
  generatedChains: [
    朝7時起床 → 洗顔, 洗顔 → コーヒー, コーヒー → ストレッチ,
    ストレッチ → 子ども朝ごはん, 子ども朝ごはん → 登園,
    登園 → 自分朝食, 自分朝食 → 仕事開始,
    子ども寝かしつけ → 23時就寝, 23時就寝 → 朝7時起床
  ],
  
  summary: "平日の健康的な朝起床（7時）と生活リズムの確立。
           週6日は23時就寝、週1回はアイドル配信視聴のため分割睡眠。
           朝のルーティンは7時起床から9時30分仕事開始まで。
           夜は22時に子どもを寝かしつけ、23時に自分が就寝。",
  
  completionPercentage: 100,  // 理想状態として設定
  readyForUsage: true,
  plannedFollowUp: "2025-01-03",  // 3日後の初回微調整
  
  startedAt: "2025-01-01T15:30:00Z",
  completedAt: "2025-01-01T17:00:00Z"
}
```

---

### A.3 利用開始時の UI/メッセージ

AI から Akira へ：

「では、このルーティンで開始します。
 
 【あなたの理想的な生活】
 
 【平日朝】
 7時起床 → 洗顔 → コーヒー → ストレッチ → 子どもの朝ごはん → 送迎 → 自分の朝食 → 9時30分仕事開始
 
 【平日夜（基本的な週6日）】
 22時に子どもを寝かしつけ → 23時に自分が就寝 → 朝7時起床
 
 【週1回（配信視聴日）】
 分割睡眠対応：23時就寝 → 25時起床 → 26時配信視聴 → 配信終了後に再就寝
 
 これが、あなたが実現したい生活ですね。
 
 ただし、最初はすべてを完璧にはできないかもしれません。
 実際に試してみて、うまくいかないことがあれば、
 一緒に工夫して、あなたに合った形に調整していきます。
 
 毎日、実行結果を教えてくださいね。
 では、頑張りましょう！」

---

## 付録 B：今後の技術選定

**推奨技術スタック：**

- **フロントエンド**：SwiftUI（iOS アプリ）or React（Web）
- **バックエンド**：Node.js/Express or Python/FastAPI
- **データベース**：PostgreSQL（RDB）+ Redis（キャッシュ/リアルタイム処理）
- **生成AI**：Claude API（gpt-4 or claude-sonnet-4）
- **NLP処理**：Claude API の機能 + 必要に応じて spaCy/Janome
- **デプロイ**：AWS/Google Cloud/Vercel

---

End of Specification Document

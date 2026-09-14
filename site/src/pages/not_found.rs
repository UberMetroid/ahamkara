//! 404.html — wished away

use crate::chrome::layout;
use crate::pick_whisper;

pub fn page_404(whispers: &[(&str, &str)]) -> String {
    let body = r##"
<section class="hero gone">
  <h1 class="hero-title">404</h1>
  <p class="hero-desc">This page was wished away. The dragon accepts no responsibility, and notes — gently — that you were the one who wished.</p>
  <p><a class="back" href="index.html">Return to the bargain &rarr;</a></p>
</section>
"##;
    layout(
        "404",
        "Wished Away",
        "This page was wished away.",
        &body,
        pick_whisper(whispers, 7),
    )
}


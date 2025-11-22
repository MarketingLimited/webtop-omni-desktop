# Frontend Module - React Landing Page

## 1. Purpose (الغرض)

هذا الـ module يحتوي على صفحة landing توثيقية مبنية بـ React + TypeScript + Vite، تعرض معلومات عن مشروع webtop-omni-desktop وتشرح كيفية استخدام بيئة Desktop Container.

**الصفحة حالياً**:
- ✅ Static documentation site
- ✅ Hero section مع project overview
- ✅ Services grid
- ✅ Features showcase
- ✅ Getting started guide
- ✅ Configuration helper
- ❌ لا توجد API calls
- ❌ لا يوجد authentication
- ❌ لا يوجد dynamic content

---

## 2. Owned Scope (النطاق المملوك)

### هذا الـ Module مسؤول عن:

**Source Code**:
- `/src/main.tsx` - React application entry point
- `/src/App.tsx` - Root component (routing + providers)
- `/src/index.css` - Global styles & design system
- `/src/vite-env.d.ts` - Vite TypeScript definitions

**Pages**:
- `/src/pages/Index.tsx` - Landing page (main)
- `/src/pages/NotFound.tsx` - 404 error page

**Components**:
- `/src/components/HeroSection.tsx` - Hero section
- `/src/components/ServicesGrid.tsx` - Services display
- `/src/components/FeaturesSection.tsx` - Features showcase
- `/src/components/GettingStarted.tsx` - Getting started guide
- `/src/components/ConfigurationHelper.tsx` - Config helper widget

**UI Library (Shadcn UI)**:
- `/src/components/ui/` - 40+ reusable UI components:
  - `button.tsx`, `card.tsx`, `dialog.tsx`, `form.tsx`
  - `input.tsx`, `label.tsx`, `select.tsx`, `textarea.tsx`
  - `accordion.tsx`, `alert.tsx`, `badge.tsx`, `breadcrumb.tsx`
  - `calendar.tsx`, `checkbox.tsx`, `collapsible.tsx`, `command.tsx`
  - `context-menu.tsx`, `dropdown-menu.tsx`, `menubar.tsx`
  - `navigation-menu.tsx`, `popover.tsx`, `radio-group.tsx`
  - `scroll-area.tsx`, `separator.tsx`, `sheet.tsx`, `skeleton.tsx`
  - `slider.tsx`, `switch.tsx`, `table.tsx`, `tabs.tsx`
  - `toast.tsx`, `toaster.tsx`, `toggle.tsx`, `tooltip.tsx`
  - ... وغيرها

**Utilities & Hooks**:
- `/src/lib/utils.ts` - Utility functions (cn, classnames)
- `/src/hooks/use-toast.ts` - Toast notifications hook
- `/src/hooks/use-mobile.tsx` - Mobile detection hook

---

## 3. Key Files & Entry Points

### Application Flow:
```
/index.html (root)
  ↓
  <script src="/src/main.tsx">
    ↓
    createRoot(document.getElementById('root'))
    ↓
    render(<App />)
      ↓
      /src/App.tsx
        ↓
        QueryClientProvider (TanStack Query)
        TooltipProvider (Radix UI)
        ThemeProvider (next-themes)
        Toaster & Sonner (notifications)
        ↓
        BrowserRouter (React Router)
          ↓
          Routes:
            "/" → <Index />
            "*" → <NotFound />
```

### Entry Point Details:

**1. HTML Entry** (`/index.html`):
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/x-icon" href="/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Webtop Omni Desktop</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

**2. JavaScript Entry** (`/src/main.tsx`):
```typescript
import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";

createRoot(document.getElementById("root")!).render(<App />);
```

**3. Application Root** (`/src/App.tsx`):
- Configures QueryClient (TanStack Query)
- Sets up theme provider
- Configures React Router
- Provides toast notifications
- Defines routes

**4. Main Page** (`/src/pages/Index.tsx`):
- Imports all section components
- Renders landing page layout

---

## 4. Dependencies & Interfaces

### Runtime Dependencies (package.json):

**Core Framework**:
```json
"react": "^18.3.1"
"react-dom": "^18.3.1"
"react-router-dom": "^6.26.2"
```

**State Management**:
```json
"@tanstack/react-query": "^5.56.2"  // Server state (not used yet)
```

**UI Components**:
```json
"@radix-ui/react-*": "^1.1.0+"     // 25+ Radix primitives
"lucide-react": "^0.462.0"         // Icons
"recharts": "^2.12.7"              // Charts (not used yet)
```

**Forms & Validation**:
```json
"react-hook-form": "^7.53.0"
"@hookform/resolvers": "^3.9.0"
"zod": "^3.23.8"
```

**Styling**:
```json
"tailwindcss": "^3.4.11"
"tailwind-merge": "^2.5.3"
"tailwindcss-animate": "^1.0.7"
"clsx": "^2.1.1"
"class-variance-authority": "^0.7.0"
```

**Theme & Utilities**:
```json
"next-themes": "^0.3.0"            // Dark mode
"sonner": "^1.5.0"                 // Toast notifications
"date-fns": "^4.1.0"               // Date utilities (not used yet)
"embla-carousel-react": "^8.3.0"   // Carousel (not used yet)
"vaul": "^1.0.0"                   // Drawer component
```

### Build Dependencies:
```json
"vite": "^5.4.1"
"@vitejs/plugin-react-swc": "^3.5.0"
"typescript": "^5.5.3"
"@types/react": "^18.3.3"
"@types/react-dom": "^18.3.0"
"@types/node": "^22.7.5"
```

### External Interfaces:

**❌ No API Calls Currently**:
- TanStack Query configured لكن لا توجد endpoints
- No backend integration
- No external services

**Browser APIs Used**:
- `window.matchMedia("(min-width: 768px)")` - Mobile detection
- Local Storage - Theme persistence (via next-themes)

---

## 5. Local Rules / Patterns

### Code Organization:

#### 1. Component Structure:
```
/src/components/
├── ui/                    # Shadcn UI primitives (don't modify directly)
├── HeroSection.tsx        # Feature components
├── ServicesGrid.tsx
└── ...
```

**Rule**: UI components في `ui/` يُنشأون بـ Shadcn CLI ولا يُعدَّلون مباشرة. للتخصيص، create wrapper components.

#### 2. Styling Pattern:
```typescript
// استخدم cn() utility لدمج classes
import { cn } from "@/lib/utils";

<div className={cn("base-classes", conditionalClass && "conditional")} />
```

#### 3. Import Aliases:
```typescript
// استخدم @ alias للـ imports
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
```

**Configured في**: `tsconfig.json` و `vite.config.ts`

#### 4. TypeScript:
```typescript
// Use strict typing
interface Props {
  title: string;
  optional?: boolean;
}

// Prefer type inference
const [state, setState] = useState(""); // inferred as string
```

#### 5. Form Handling:
```typescript
// Use React Hook Form + Zod
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";

const schema = z.object({
  name: z.string().min(1, "Required"),
});

const form = useForm({
  resolver: zodResolver(schema),
});
```

### Design System (index.css):

**CSS Variables** (HSL colors):
```css
:root {
  --background: 0 0% 100%;
  --foreground: 240 10% 3.9%;
  --primary: 240 5.9% 10%;
  /* ... more variables */
}

.dark {
  --background: 240 10% 3.9%;
  --foreground: 0 0% 98%;
  /* ... dark mode overrides */
}
```

**Usage في Components**:
```typescript
<div className="bg-background text-foreground" />
<Button variant="default" />  // uses --primary
```

### Routing Pattern:
```typescript
// في App.tsx
<Routes>
  <Route path="/" element={<Index />} />
  <Route path="*" element={<NotFound />} />
</Routes>

// To add new route:
<Route path="/about" element={<About />} />
```

---

## 6. How to Run / Test

### Development Server:

```bash
# Install dependencies (first time)
npm install

# Start dev server
npm run dev
# Opens: http://localhost:8080
# Hot reload enabled (Vite HMR)

# Check for errors in console
# Browser DevTools: F12
```

### Production Build:

```bash
# Build for production
npm run build
# Output: dist/ directory

# Preview production build locally
npm run preview
# Opens: http://localhost:4173

# Build artifacts:
# dist/index.html
# dist/assets/*.js (bundled & minified)
# dist/assets/*.css (processed & minified)
```

### Linting:

```bash
# Run ESLint
npm run lint

# Fix auto-fixable issues
npm run lint -- --fix
```

### Development Workflow:

```bash
# 1. Start dev server
npm run dev

# 2. Open browser: http://localhost:8080

# 3. Edit files in src/
#    - Changes auto-reload via HMR
#    - Check browser console for errors

# 4. Test responsive design
#    - Browser DevTools → Device toolbar
#    - Test mobile, tablet, desktop

# 5. Test dark mode
#    - Toggle theme (if theme switcher added)
#    - Or system preference

# 6. Before commit
npm run lint        # Check for errors
npm run build       # Ensure build succeeds
```

### Testing Individual Components:

**Assumption**: No unit tests currently configured.

**To add testing**:
```bash
# Install Vitest
npm install -D vitest @testing-library/react @testing-library/jest-dom

# Add script to package.json
"test": "vitest"
```

---

## 7. Common Tasks for Agents

### Task 1: إضافة Component جديد

```bash
# 1. Create component file
touch src/components/NewSection.tsx

# 2. Write component
cat > src/components/NewSection.tsx << 'EOF'
export const NewSection = () => {
  return (
    <section className="py-12 bg-background">
      <div className="container mx-auto">
        <h2 className="text-3xl font-bold">New Section</h2>
      </div>
    </section>
  );
};
EOF

# 3. Import في Index.tsx
# Add: import { NewSection } from "@/components/NewSection";
# Add: <NewSection /> في المكان المناسب

# 4. Test
npm run dev
```

### Task 2: إضافة Shadcn UI Component

```bash
# استخدم Shadcn CLI
npx shadcn@latest add <component-name>

# مثال: إضافة dialog
npx shadcn@latest add dialog

# Component يُنشأ في: src/components/ui/dialog.tsx
# استخدمه في code:
# import { Dialog, DialogContent } from "@/components/ui/dialog";
```

### Task 3: إضافة Route جديد

```bash
# 1. Create page component
touch src/pages/About.tsx

# 2. Write page
cat > src/pages/About.tsx << 'EOF'
export default function About() {
  return (
    <div className="container mx-auto py-12">
      <h1 className="text-4xl font-bold">About Us</h1>
    </div>
  );
}
EOF

# 3. Add route في App.tsx
# Import: import About from "./pages/About";
# Add route: <Route path="/about" element={<About />} />

# 4. Test
npm run dev
# Navigate to: http://localhost:8080/about
```

### Task 4: تعديل Design System Colors

```bash
# Edit src/index.css
# Modify CSS variables:

:root {
  --primary: 210 100% 50%;  /* Change primary color */
}

# Colors use HSL format: hue saturation lightness
# Changes apply globally to all components
```

### Task 5: إضافة API Integration

```bash
# 1. Create API client
mkdir -p src/lib
touch src/lib/api.ts

# 2. Define API functions
cat > src/lib/api.ts << 'EOF'
export async function fetchData() {
  const response = await fetch('https://api.example.com/data');
  return response.json();
}
EOF

# 3. Use with TanStack Query في Component
import { useQuery } from '@tanstack/react-query';
import { fetchData } from '@/lib/api';

function MyComponent() {
  const { data, isLoading } = useQuery({
    queryKey: ['data'],
    queryFn: fetchData,
  });

  // ...
}
```

### Task 6: تحسين Performance

```bash
# 1. Code splitting بـ lazy loading
# في App.tsx:
import { lazy, Suspense } from 'react';

const About = lazy(() => import('./pages/About'));

<Route path="/about" element={
  <Suspense fallback={<div>Loading...</div>}>
    <About />
  </Suspense>
} />

# 2. Optimize images
# - استخدم WebP format
# - Add loading="lazy"
# - Use appropriate sizes

# 3. Analyze bundle
npm run build
# Check dist/assets/ sizes
```

### Task 7: إضافة Dark Mode Toggle

```bash
# 1. Create theme toggle component
touch src/components/ThemeToggle.tsx

# 2. Implement toggle
cat > src/components/ThemeToggle.tsx << 'EOF'
import { Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { Button } from "@/components/ui/button";

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
    >
      <Sun className="h-5 w-5 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
      <Moon className="absolute h-5 w-5 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
    </Button>
  );
}
EOF

# 3. Add to layout
# Import في Index.tsx وضعه في navbar
```

---

## 8. Notes / Gotchas

### ⚠️ Important Points:

#### 1. Shadcn UI Components:
- **لا تُعدَّل** components في `src/components/ui/` مباشرة
- عند تحديث Shadcn، التعديلات المباشرة تُفقد
- **بدلاً من ذلك**: Create wrapper components
```typescript
// ❌ Bad
// Edit src/components/ui/button.tsx directly

// ✅ Good
// Create src/components/CustomButton.tsx
import { Button } from "@/components/ui/button";

export function CustomButton(props) {
  return <Button className="custom-styles" {...props} />;
}
```

#### 2. Import Aliases:
- استخدم `@/` للـ imports من `src/`
- **Don't use** relative imports `../../` عبر directories
```typescript
// ✅ Good
import { Button } from "@/components/ui/button";

// ❌ Bad
import { Button } from "../../components/ui/button";
```

#### 3. CSS Variables:
- جميع الـ colors معرفة كـ HSL values
- Format: `hue saturation lightness` (no units)
- Used via Tailwind classes: `bg-primary`, `text-foreground`

#### 4. TanStack Query:
- Configured لكن **لا توجد queries حالياً**
- QueryClient في App.tsx جاهز للاستخدام
- Default staleTime: 0 (data always stale)

#### 5. React Router:
- Uses BrowserRouter (**not** HashRouter)
- Server must serve `index.html` for all routes في production
- Vite dev server يتعامل مع هذا تلقائياً

#### 6. TypeScript:
- Strict mode enabled
- Use `npm run build` للكشف عن type errors
- ESLint checks types أيضاً

#### 7. Build Output:
- `dist/` directory يُحذف عند كل build
- Don't commit `dist/` to git
- Asset filenames تحتوي على hash للـ cache busting

#### 8. Environment Variables:
- Vite exposes only `VITE_*` prefixed vars
- Access via `import.meta.env.VITE_API_URL`
- **Assumption**: لا توجد env vars مُعرَّفة حالياً

#### 9. Hot Module Replacement (HMR):
- Vite HMR سريع جداً
- State preservation عند edit
- أحياناً full reload مطلوب (edit index.html, vite.config.ts)

#### 10. Mobile Responsiveness:
- Tailwind breakpoints:
  - `sm:` 640px
  - `md:` 768px
  - `lg:` 1024px
  - `xl:` 1280px
  - `2xl:` 1536px
- Design mobile-first: default styles للـ mobile، breakpoints للـ larger screens

#### 11. Accessibility:
- Radix UI components accessible by default
- Test keyboard navigation (Tab, Enter, Escape)
- Screen reader testing recommended

#### 12. Performance:
- Vite production build يُحسّن تلقائياً
- Code splitting via dynamic imports
- Tree shaking enabled
- Check bundle size: `dist/assets/*.js`

---

## Development Tips

### VS Code Extensions (Recommended):
- **ES7+ React/Redux/React-Native snippets**
- **Tailwind CSS IntelliSense**
- **ESLint**
- **Prettier**
- **TypeScript Vue Plugin (Volar)** - للـ TypeScript support

### Browser DevTools:
- **React DevTools**: Debug component tree
- **TanStack Query DevTools**: Monitor queries (add to App.tsx)
```typescript
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';

// في App.tsx
<QueryClientProvider client={queryClient}>
  {/* ... */}
  <ReactQueryDevtools initialIsOpen={false} />
</QueryClientProvider>
```

### Common Errors:

**Error**: `Module not found: Can't resolve '@/...'`
- **Fix**: Check tsconfig.json و vite.config.ts للـ path alias config

**Error**: `Cannot find module 'X' or its corresponding type declarations`
- **Fix**: `npm install @types/X` أو check package.json

**Error**: `Hydration failed` (unlikely في هذا المشروع)
- **Fix**: Check for server/client mismatch (نحن client-only SPA)

**Error**: Build fails silently
- **Fix**: Run `npm run lint` أولاً للكشف عن errors

---

## Quick Reference

### File Structure:
```
src/
├── main.tsx              # Entry point
├── App.tsx               # Root component
├── index.css             # Global styles
├── pages/
│   ├── Index.tsx        # Landing page
│   └── NotFound.tsx     # 404
├── components/
│   ├── ui/              # Shadcn components (40+)
│   └── [features]       # Feature components
├── hooks/               # Custom hooks
└── lib/
    └── utils.ts         # Utilities
```

### Key Commands:
| Command | Purpose |
|---------|---------|
| `npm run dev` | Start dev server (port 8080) |
| `npm run build` | Production build → dist/ |
| `npm run preview` | Preview production build |
| `npm run lint` | Run ESLint |
| `npx shadcn@latest add <component>` | Add UI component |

### Common Imports:
```typescript
// UI Components
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";

// Hooks
import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";

// Utils
import { cn } from "@/lib/utils";
```

---

**Module Type**: Frontend - React SPA
**Tech Stack**: React 18 + TypeScript + Vite + Tailwind + Shadcn UI
**Entry Point**: `/src/main.tsx`
**Build Output**: `/dist/`
**Dev Server**: http://localhost:8080
**Last Updated**: 2025-11-22

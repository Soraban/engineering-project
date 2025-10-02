# Bookkeeping System - Frontend

A modern React frontend for the bookkeeping system with transaction management, automated categorization, and anomaly detection review.

## Features

✅ **Dashboard** - Overview of transactions needing review
✅ **Transaction Management** - List, filter, and manage transactions
✅ **CSV Import** - Bulk import transactions from CSV files
✅ **Bulk Categorization** - Categorize multiple transactions at once
✅ **Category Management** - Create and manage transaction categories
✅ **Rule Management** - Set up automated categorization rules
✅ **Anomaly Detection Review** - Review flagged suspicious transactions
✅ **Responsive Design** - Works on desktop and mobile devices

## Tech Stack

- **React** 18+
- **Vite** - Fast build tool
- **React Router** - Client-side routing
- **Axios** - HTTP client
- **Tailwind CSS** - Utility-first CSS framework

## Prerequisites

- Node.js 20+
- npm or yarn
- Backend API running (see backend README)

## Installation

1. **Navigate to frontend directory**
   ```bash
   cd frontend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env if your backend is not on http://localhost:3000
   ```

4. **Start development server**
   ```bash
   npm run dev
   ```

The app will be available at `http://localhost:5173`

## Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build
- `npm run lint` - Run ESLint

## Project Structure

```
frontend/
├── src/
│   ├── components/       # Reusable components
│   │   ├── Layout.jsx
│   │   ├── CSVImport.jsx
│   │   └── BulkCategorize.jsx
│   ├── pages/            # Page components
│   │   ├── Dashboard.jsx
│   │   ├── Transactions.jsx
│   │   ├── Categories.jsx
│   │   └── Rules.jsx
│   ├── services/         # API services
│   │   └── api.js
│   ├── App.jsx           # Main app component
│   └── main.jsx          # Entry point
├── public/               # Static assets
└── package.json
```

## Features Guide

### Dashboard

The dashboard provides an overview of your bookkeeping system:
- **Uncategorized Transactions** - Transactions without categories
- **Flagged Anomalies** - Suspicious transactions detected by the system
- **Needs Review** - All transactions requiring attention

### Transactions

Manage all your transactions:
- **Filter** - By category, uncategorized, or flagged status
- **Bulk Select** - Select multiple transactions for bulk actions
- **Import CSV** - Upload CSV files with transaction data
- **Bulk Categorize** - Assign categories to multiple transactions at once

### Categories

Organize transactions into categories:
- **Create Categories** - Add custom categories with colors
- **Edit Categories** - Update category names and colors
- **Delete Categories** - Remove unused categories

### Rules

Automate transaction categorization:
- **Create Rules** - Set up conditions and actions
- **Condition Types**:
  - Description contains text
  - Amount greater than value
  - Amount less than value
  - Amount equals value
- **Action Types**:
  - Categorize - Auto-assign category
  - Flag - Mark as anomaly
- **Apply Rules** - Run rules on existing transactions
- **Priority** - Control rule execution order

## CSV Import Format

Your CSV file should have these columns:

```csv
date,description,amount
2025-01-15,Amazon.com Purchase,299.99
2025-01-16,Starbucks Coffee,5.50
2025-01-17,Uber Ride,23.45
```

- **date** or **transaction_date** - Date of transaction
- **description** - Transaction description (optional)
- **amount** - Transaction amount (required)

## API Configuration

The frontend connects to the backend API using the base URL configured in `.env`:

```
VITE_API_BASE_URL=http://localhost:3000/api/v1
```

Change this if your backend is hosted elsewhere.

## Building for Production

1. **Build the app**
   ```bash
   npm run build
   ```

2. **Preview the build**
   ```bash
   npm run preview
   ```

The build output will be in the `dist/` directory, ready to deploy to any static hosting service.

## Deployment

### Deploy to Netlify

1. Connect your repository to Netlify
2. Set build command: `npm run build`
3. Set publish directory: `dist`
4. Add environment variable: `VITE_API_BASE_URL=<your-backend-url>`

### Deploy to Vercel

1. Connect your repository to Vercel
2. Build command: `npm run build`
3. Output directory: `dist`
4. Add environment variable: `VITE_API_BASE_URL=<your-backend-url>`

## Customization

### Colors

Categories use custom colors. Edit the color picker presets in `src/pages/Categories.jsx`:

```javascript
const colorPresets = [
  '#FF6B6B', '#4ECDC4', '#45B7D1', // Add your colors here
];
```

### Styling

This project uses Tailwind CSS. Customize styles in `tailwind.config.js`:

```javascript
export default {
  theme: {
    extend: {
      // Your customizations
    },
  },
}
```

## Troubleshooting

### Cannot connect to backend

- Ensure backend is running on `http://localhost:3000`
- Check CORS settings in backend
- Verify `VITE_API_BASE_URL` in `.env`

### Port already in use

```bash
npm run dev -- --port 3001
```

### Build errors

```bash
rm -rf node_modules package-lock.json
npm install
npm run build
```

## Browser Support

- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)

## License

MIT

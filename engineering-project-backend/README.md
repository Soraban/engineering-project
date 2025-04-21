# Running the Backend Server

1. **After you are in the app location**, run `npm install` to install dependencies.
2. **Configure environment**:
   - Copy `.env.example` to `.env`.
   - Adjust variables as needed, including `DATABASE_URL`.
     - Example for `DATABASE_URL`:
       ```
       DATABASE_URL="mysql://<username>:<password>@localhost:3306/transaction-application"
       ```
     - Replace `<username>` and `<password>` with your MySQL credentials.
     - Ensure that the MySQL server is running and the database name matches your setup.
3. **Set up Prisma**:
   - Run `npx prisma migrate dev` to apply the database schema.
   - If needed, run `npx prisma generate` to regenerate the Prisma client.
4. **Start the server**: Run `npm run dev` to start the backend server on port 5001.
5. The backend will be accessible at `http://localhost:5001`.

---

### Learn More

For more information about the setup and Prisma:

- [Prisma Documentation](https://www.prisma.io/docs) - Learn how to use Prisma with your database.

---

### Deployment

To deploy the app, you can choose a hosting provider that supports Node.js and MySQL.

Check out the [Prisma deployment documentation](https://www.prisma.io/docs/guides/hosting) for more details.

---
